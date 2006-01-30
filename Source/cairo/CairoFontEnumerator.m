/*
 * CairoFontEnumerator.m
 *
 * Copyright (C) 2003 Free Software Foundation, Inc.
 * August 31, 2003
 * Written by Banlu Kemiyatorn <object at gmail dot com>
 * Base on original code of Alex Malmberg
 * Rewrite: Fred Kiefer <fredkiefer@gmx.de>
 * Date: Jan 2006
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.

 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.

 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the Free
 * Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include <Foundation/NSObject.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSSet.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSPathUtilities.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSUserDefaults.h>
#include <Foundation/NSBundle.h>
#include <Foundation/NSDebug.h>
#include <GNUstepGUI/GSFontInfo.h>
#include <AppKit/NSAffineTransform.h>
#include <AppKit/NSBezierPath.h>

#include "gsc/GSGState.h"
#include "cairo/CairoFontEnumerator.h"
#include "cairo/CairoFontInfo.h"

@implementation CairoFontEnumerator 

NSMutableDictionary * __allFonts;

+ (CairoFaceInfo *) fontWithName: (NSString *) name
{
  CairoFaceInfo *face;

  face =[__allFonts objectForKey: name];
  if (!face)
    {
      NSLog (@"Font not found %@", name);
    }
  return face;
}

// Make a GNUStep style font descriptor from a FcPattern
static NSArray *faFromFc(FcPattern *pat)
{
  int weight, slant, spacing, nsweight;
  unsigned int nstraits = 0;
  char *family;
  NSMutableString *name, *style;

  if (FcPatternGetInteger(pat, FC_WEIGHT, 0, &weight) != FcResultMatch ||
      FcPatternGetInteger(pat, FC_SLANT,  0, &slant) != FcResultMatch ||
      FcPatternGetString(pat, FC_FAMILY, 0, (FcChar8 **)&family) != FcResultMatch)
    return nil;

  if (FcPatternGetInteger(pat, FC_SPACING, 0, &spacing) == FcResultMatch)
    if (spacing==FC_MONO || spacing==FC_CHARCELL)
      nstraits |= NSFixedPitchFontMask;
  
  name = [NSMutableString stringWithCapacity: 100];
  style = [NSMutableString stringWithCapacity: 100];
  [name appendString: [NSString stringWithUTF8String: family]];

  switch (weight) 
    {
    case FC_WEIGHT_LIGHT:
      [style appendString: @"Light"];
      nsweight = 3;
      break;
    case FC_WEIGHT_MEDIUM:
      nsweight = 6;
      break;
    case FC_WEIGHT_DEMIBOLD:
      [style appendString: @"Demibold"];
      nsweight = 7;
      break;
    case FC_WEIGHT_BOLD:
      [style appendString: @"Bold"];
      nsweight = 9;
      nstraits |= NSBoldFontMask;
      break;
    case FC_WEIGHT_BLACK:
      [style appendString: @"Black"];
      nsweight = 12;
      nstraits |= NSBoldFontMask;
      break;
    default:
      nsweight = 6;
    }

  switch (slant) 
    {
    case FC_SLANT_ROMAN:
      break;
    case FC_SLANT_ITALIC:
      [style appendString: @"Italic"];
      nstraits |= NSItalicFontMask;
      break;
    case FC_SLANT_OBLIQUE:
      [style appendString: @"Oblique"];
      nstraits |= NSItalicFontMask;
      break;
    }

  if ([style length] > 0)
    {
      [name appendString: @"-"];
      [name appendString: style];
    }
  else
    {
      [style appendString: @"Roman"];
    }

  return [NSArray arrayWithObjects: name, 
		  style, 
		  [NSNumber numberWithInt: nsweight], 
		  [NSNumber numberWithUnsignedInt: nstraits],
		  nil];
}

- (void) enumerateFontsAndFamilies
{
  int i;
  NSMutableDictionary *fcxft_allFontFamilies = [[NSMutableDictionary alloc] init];
  NSMutableDictionary *fcxft_allFonts = [[NSMutableDictionary alloc] init];
  NSMutableArray *fcxft_allFontNames = [[NSMutableArray alloc] init];

  FcPattern *pat = FcPatternCreate();
  FcObjectSet *os = FcObjectSetBuild(FC_FAMILY, FC_SLANT, FC_WEIGHT, NULL);
  FcFontSet *fs = FcFontList(NULL, pat, os);

  FcPatternDestroy(pat);
  FcObjectSetDestroy(os);

  for (i=0; i < fs->nfont; i++)
    {
      char *family;

      if (FcPatternGetString(fs->fonts[i], FC_FAMILY, 0, (FcChar8 **)&family) == FcResultMatch)
        {
          NSArray *fontArray;

          if ((fontArray = faFromFc(fs->fonts[i])))
            {
              NSString *familyString;
              NSMutableArray *familyArray;
              CairoFaceInfo *aFont;
              NSString *name = [fontArray objectAtIndex: 0];

              familyString = [NSString stringWithUTF8String: family];
              if (!(familyArray = [fcxft_allFontFamilies objectForKey: familyString]))
                {
									NSDebugLog(@"Found font family %@", familyString);
                  familyArray = [[NSMutableArray alloc] init];
                  [fcxft_allFontFamilies setObject: familyArray forKey: familyString];
                  RELEASE(familyArray);
                }
              NSDebugLog(@"fc enumerator: adding font: %@", name);
              [familyArray addObject: fontArray];
              [fcxft_allFontNames addObject: name];      
              aFont = [[CairoFaceInfo alloc] initWithfamilyName: familyString
																						 weight: [[fontArray objectAtIndex: 2] intValue]
																						 traits: [[fontArray objectAtIndex: 3] unsignedIntValue]
																						 pattern: fs->fonts[i]];
              [fcxft_allFonts setObject: aFont forKey: name];
              RELEASE(aFont);
            }
        }
    }
  FcFontSetDestroy (fs); 

  allFontNames = fcxft_allFontNames;
  allFontFamilies = fcxft_allFontFamilies;
  __allFonts = fcxft_allFonts;
}

-(NSString *) defaultSystemFontName
{
  if ([allFontNames containsObject: @"Bitstream Vera Sans"])
    return @"Bitstream Vera Sans";
  if ([allFontNames containsObject: @"FreeSans"])
    return @"FreeSans";
  return @"Helvetica";
}

-(NSString *) defaultBoldSystemFontName
{
  if ([allFontNames containsObject: @"Bitstream Vera Sans-Bold"])
    return @"Bitstream Vera Sans-Bold";
  if ([allFontNames containsObject: @"FreeSans-Bold"])
    return @"FreeSans-Bold";
  return @"Helvetica-Bold";
}

-(NSString *) defaultFixedPitchFontName
{
  if ([allFontNames containsObject: @"Bitstream Vera Sans Mono"])
    return @"Bitstream Vera Sans Mono";
  if ([allFontNames containsObject: @"FreeMono"])
    return @"FreeMono";
  return @"Courier";
}

@end
