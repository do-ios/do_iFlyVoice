//
//  do_iFlyVoice_App.m
//  DoExt_SM
//
//  Created by @userName on @time.
//  Copyright (c) 2015年 DoExt. All rights reserved.
//

#import "do_iFlyVoice_App.h"
static do_iFlyVoice_App* instance;
@implementation do_iFlyVoice_App
@synthesize OpenURLScheme;
+(id) Instance
{
    if(instance==nil)
        instance = [[do_iFlyVoice_App alloc]init];
    return instance;
}
@end
