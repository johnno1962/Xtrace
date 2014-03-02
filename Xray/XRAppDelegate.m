//
//  XRAppDelegate.m
//  Xray
//
//  Created by John Holdsworth on 28/02/2014.
//  Copyright (c) 2014 John Holdsworth. All rights reserved.
//

#import "XRAppDelegate.h"

@implementation XRAppDelegate

- (void)simple {
    NSLog( @"%p %p", &self, &_cmd );
}

- (void)simple:(CGRect)a {
    NSLog( @"%p %p %p", &self, &_cmd, &a );
    NSLog(@"%@",NSStringFromCGRect(*&a));
}

- (void)simple:(CGRect)a i:(int)i1 i:(int)i2 {
    NSLog( @"%p %p %p %p %p", &self, &_cmd, &a, &i1, &i2 );
    NSLog(@"%@",NSStringFromCGRect(*&a));
}

- (void)i:(int)i1 i:(int)i2 simple:(CGRect)a {
    NSLog( @"%p %p %p %p %p", &self, &_cmd, &a, &i1, &i2 );
    NSLog(@"%@",NSStringFromCGRect(*&a));
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    //[Xtrace methodFilter:"set"];
    [Xtrace showArguments:YES];
    //[Xtrace hideReturns:YES];
    [XRAppDelegate xtrace];
    [self simple];
    CGRect a = {{111,222},{333,444}};
    a.origin.x= 99;
    NSLog(@"%@",NSStringFromCGRect(a));
    [self simple:a];
    [self simple:a i:11 i:22];
    [self i:1 i:2 simple:a];
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
