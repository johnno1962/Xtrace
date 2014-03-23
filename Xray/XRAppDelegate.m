//
//  XRAppDelegate.m
//  Xray
//
//  Created by John Holdsworth on 28/02/2014.
//  Copyright (c) 2014 John Holdsworth. All rights reserved.
//

#import "XRAppDelegate.h"

@interface XtraceCallbacks : NSObject
@end
@implementation XtraceCallbacks

+ (void)before:(XRAppDelegate *)obj simple:(CGRect)a i:(int)i1 i:(int)i2 {
    NSLog( @"before:simple:i:i: %p %p %p %p %p %d %d %@", &self, &_cmd, &a, &i1, &i2, i1, i2, NSStringFromCGRect(*&a) );
    assert(i1==11);
    assert(i2==22);
#ifndef __LP64__
    assert(a.origin.x=99);
#else
    assert(a.origin.y=99); // frame problem with CGRect on 64 bits
#endif
}

+ (void)after:(XRAppDelegate *)obj i:(int)i1 i:(int)i2 simple:(CGRect)a {
    NSLog( @"after:i:i:simple: %p %p %p %p %p %d %d %@", &self, &_cmd, &a, &i1, &i2, i1, i2, NSStringFromCGRect(*&a) );
    assert(i1==1);
    assert(i2==2);
#ifndef __LP64__
    assert(a.origin.x=99);
#else
    assert(a.origin.y=99); // frame problem with CGRect on 64 bits
#endif
}

+ (NSString *)after:(NSString *)out obj:(XRAppDelegate *)obj msg:(NSString *)msg {
    NSLog( @"after:obj:msg: %@ -> %@", msg, out );
    return [NSString stringWithFormat:@"%@, %@", out, @"hello aspect"];
}

+ (void)label:(UILabel *)label setText:(NSString *)text {
    label.textColor = [UIColor redColor];
}

+ (NSString *)out:(NSString *)text labelText:(UILabel *)label {
    NSLog(@"UILabel text: %@", text);
    return text;
}

+ (CGRect)out:(CGRect)out obj:(XRAppDelegate *)obj rect:(CGRect)rect shift:(int)offset {
    out.origin.x += offset;
    return out;
}

+ (unsigned char)out:(unsigned char)out obj:(XRAppDelegate *)obj frame:(char)i1 frame:(char)i2 rect:(CGRect)a char:(unsigned char)i3 {
    NSLog( @"out:obj:frame:frame:rect:char: %d %d %d %d", out, i1, i2, i3 );
#ifdef __LP64__
    i3 = 222; // frame problem on 64 bits
#endif
    return out-i3;
}

static NSString *expect;

+ (void)xtraceLog:(NSString *)trace {
    printf( "| %s\n", [trace UTF8String] );
    if ( expect )
        assert( [trace rangeOfString:expect].location != NSNotFound );
    expect = nil;
}

@end

@implementation XRAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    [Xtrace dumpClass:[UITableView class]];

    // the various options..
    //[Xtrace methodFilter:"^set"];
    //[Xtrace describeValues:YES];
    //[Xtrace hideReturns:YES];

    [Xtrace showArguments:YES];
    [UINavigationController xtrace];

    // delegate must not have been traced.
    [Xtrace setDelegate:[XtraceCallbacks class]];

    // this exploratory code has rather evolved into the unit tests...

    [Xtrace forClass:[XRAppDelegate class] before:@selector(simple:i:i:) callback:@selector(before:simple:i:i:)];

    CGRect a = {{111,222},{333,444}};
    a.origin.x= 99;
    NSLog(@"CGRect: %@",NSStringFromCGRect(a));

    [self simple:a i:11 i:22];
    [XRAppDelegate xtrace];
    [Xtrace forClass:[self class] after:@selector(i:i:simple:) callback:@selector(after:i:i:simple:)];

    expect = @"> i:1 i:2 simple:{{99, 222}, {333, 444}}]";
    [self i:1 i:2 simple:a];

    expect = @"> simple]";
    [self simple];

    expect = @"> simple:{{99, 222}, {333, 444}}]";
    [self simple:a];

    [Xtrace forClass:[self class] after:@selector(msg:) callback:@selector(after:obj:msg:)];

    expect = @"> msg:<__NSCFConstantString 0x";
    assert([[self msg:@"hello world"] isEqual:@"hello world, hello aspect"]);
    NSLog( @"Caller: %s", [Xtrace callerFor:[self class] sel:@selector(msg:)] );

    [Xtrace forClass:[UILabel class] after:@selector(setText:) callback:@selector(label:setText:)];
    [Xtrace forClass:[UILabel class] after:@selector(text) callback:@selector(out:labelText:)];

#ifdef __LP64__
    expect = @"> long:1L] q";
#else
    expect = @"> long:1L] l";
#endif
    assert([self long:1L]==1);
#ifdef __LP64__
    expect = @"> longLong:1L] q";
#else
    expect = @"> longLong:1LL] q";
#endif
    assert([self longLong:1LL]==1);

    assert([Xtrace infoFor:[self class] sel:@selector(long:)]->stats.callCount==1);

    [Xtrace forClass:[self class] after:@selector(frame:frame:rect:char:) callback:@selector(out:obj:frame:frame:rect:char:)];

    expect = @"> frame:111 frame:121 rect:{{99, 222}, {333, 444}} char:222]";
    assert([self frame:111 frame:121 rect:a char:222]==0);

    [Xtrace forClass:[self class] after:@selector(rect:shift:) callback:@selector(out:obj:rect:shift:)];

#ifndef __LP64__
    expect = @"> rect:{{99, 222}, {333, 444}} shift:1]";
#endif
    assert([self rect:a shift:1].origin.x==a.origin.x+1);

#if 0
    // For use with the "XcodeColors" plugin.
    // https://github.com/robbiehanson/XcodeColors
    [Xtrace useColor:XTRACE_GREEN"\033[bg100,100,100;" forSelector:@selector(initialize)];
    [Xtrace useColor:XTRACE_RED forClass:[UITableViewCell class]];
    [Xtrace useColor:"\033[fg200,0,200;" forClass:[UIScreen class]];
    [Xtrace useColor:"\033[fg0,200,0;" forClass:[UIWindow class]];
    [Xtrace useColor:"\033[fg0,200,100;" forClass:[UILabel class]];

    [Xtrace useColor:"\033[fg100,100,0;"];
#endif

    // go on then, let's just trace (almost) the lot...
    [Xtrace traceClassPattern:@"^UI" excluding:@"UIKeyboardCandidateUtilities"];

    return YES;
}
							
// testing ARC stack layout - seems very strange

- (void)simple {
    NSLog( @"simple %p %p", &self, &_cmd );
}

- (void)simple:(CGRect)a {
    NSLog( @"simple: %p %p %p", &self, &_cmd, &a );
    assert(a.origin.x=99);
}

- (void)simple:(CGRect)a i:(int)i1 i:(int)i2 {
    NSLog( @"simple:i:i: %p %p %p %p %p", &self, &_cmd, &a, &i1, &i2 );
    assert(i1=11);
    assert(a.origin.x=99);
}

- (void)i:(int)i1 i:(int)i2 simple:(CGRect)a {
    NSLog( @"i:i:simple: %p %p %p %p %p", &self, &_cmd, &a, &i1, &i2 );
    assert(i1=1);
    assert(a.origin.x=99);
}

- (NSString *)msg:(NSString *)msg {
    return msg;
}

- (CGRect)rect:(CGRect)rect shift:(int)offset {
    return rect;
}

- (long)long:(unsigned long)l {
    return 1;
}

- (long long)longLong:(unsigned long long)l {
    return 1;
}

- (unsigned char)frame:(char)i1 frame:(char)i2 rect:(CGRect)a char:(unsigned char)i3 {
    return i3;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    [Xtrace dumpProfile:100 dp:6];
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
