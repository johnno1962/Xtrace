//
//  XRAppDelegate.m
//  Xray
//
//  Created by John Holdsworth on 28/02/2014.
//  Copyright (c) 2014 John Holdsworth. All rights reserved.
//

#import "XRAppDelegate.h"

@implementation UIApplication(XtraceDelegate)

- (void)before:(XRAppDelegate *)obj simple:(CGRect)a i:(int)i1 i:(int)i2 {
    NSLog( @"before:simple:i:i: %p %p %p %p %p %d %d %@", &self, &_cmd, &a, &i1, &i2, i1, i2, NSStringFromCGRect(a) );
}

- (void)after:(XRAppDelegate *)obj i:(int)i1 i:(int)i2 simple:(CGRect)a {
    NSLog( @"after:i:i:simple: %p %p %p %p %p %d %d %@", &self, &_cmd, &a, &i1, &i2, i1, i2, NSStringFromCGRect(a) );
}

- (const char *)after:(const char *)out obj:(XRAppDelegate *)obj msg:(const char *)msg {
    NSLog( @"after:obj:msg: %s", msg );
    return "hello aspect";
}

- (void)label:(UILabel *)label setText:(NSString *)text {
    label.textColor = [UIColor redColor];
}

@end

@implementation XRAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.

    // the various options..
    //[Xtrace methodFilter:"^set"];
    //[Xtrace describeValues:YES];
    //[Xtrace hideReturns:YES];

    [Xtrace showArguments:YES];

    // setup trace before callbacks
    // delegate must not be traced.
    [Xtrace setDelegate:application];
    [Xtrace forClass:[XRAppDelegate class] before:@selector(simple:i:i:) perform:@selector(before:simple:i:i:)];

    CGRect a = {{111,222},{333,444}};
    a.origin.x= 99;
    NSLog(@"CGRect: %@",NSStringFromCGRect(a));

    [self simple:a i:11 i:22];
    [XRAppDelegate xtrace];
    [Xtrace forClass:[XRAppDelegate class] after:@selector(i:i:simple:) perform:@selector(after:i:i:simple:)];
    [self i:1 i:2 simple:a];

    [self simple];
    [self simple:a];

    [Xtrace forClass:[XRAppDelegate class] after:@selector(msg:) perform:@selector(after:obj:msg:)];
    NSLog( @"%s", [self msg:"hello world"] );

    [Xtrace forClass:[UILabel class] after:@selector(setText:) perform:@selector(label:setText:)];

    return YES;
}
							
// testing ARC stack layout - seems very strange
// NOTE: CGRect structures are logged backwards!

- (void)simple {
    NSLog( @"simple %p %p", &self, &_cmd );
}

- (void)simple:(CGRect)a {
    NSLog( @"simple: %p %p %p", &self, &_cmd, &a );
}

- (void)simple:(CGRect)a i:(int)i1 i:(int)i2 {
    NSLog( @"simple:i:i: %p %p %p %p %p", &self, &_cmd, &a, &i1, &i2 );
}

- (void)i:(int)i1 i:(int)i2 simple:(CGRect)a {
    NSLog( @"i:i:simple: %p %p %p %p %p", &self, &_cmd, &a, &i1, &i2 );
}

- (const char *)msg:(const char *)msg {
    return msg;
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
