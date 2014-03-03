//
//  Xtrace.h
//  Xtrace
//
//  Created by John Holdsworth on 28/02/2014.
//  Copyright (c) 2014 John Holdsworth. All rights reserved.
//
//  $Id: //depot/Xtrace/Xray/Xtrace.h#4 $
//
//  Class to intercept messages sent to a class or object.
//  Swizzles generic logging implemntation in place of the
//  original which is called after logging the message.
//
//  Implemented as category  on NSObject so message the
//  class or instance you want to log for example:
//
//  Log all messages of the navigation controller class
//  and it's superclasses:
//  [UINavigationController xtrace]
//
//  Log all messages sent to objects instance1/2
//  [instance1 xtrace];
//  [instance2 xtrace];
//
//  Instance tracing takes priority.
//

#ifdef DEBUG
#ifdef __OBJC__
#import <Foundation/Foundation.h>

@interface NSObject(Xtrace)

// avoid a class
+ (void)notrace;

// trace class or..
+ (void)xtrace;

// trace instance
- (void)xtrace;

// stop tacing "
- (void)untrace;

@end

// implementing class
@interface Xtrace : NSObject

// delegate for callbacks
+ (void)setDelegate:delegate;

// hide log of return values
+ (void)hideReturns:(BOOL)hide;

// attempt log of call arguments
+ (void)showArguments:(BOOL)show;

// log values's "description"
+ (void)describeValues:(BOOL)desc;

// property methods filtered out by default
+ (void)includeProperties:(BOOL)include;

// intercept only methods matching pattern
+ (void)methodFilter:(const char *)pattern;

// don't trace this class e.g. [UIView notrace]
+ (void)dontTrace:(Class)aClass;

// trace class down to NSObject
+ (void)traceClass:(Class)aClass;

// trace class down to "levels" of superclases
+ (void)traceClass:(Class)aClass levels:(int)levels;

// trace all messages sent to an instance
+ (void)traceInstance:(id)instance;

// stop tracing messages to instance
+ (void)untrace:(id)instance;

// callbacks
+ (void)forClass:(Class)aClass before:(SEL)sel perform:(SEL)callback;
+ (void)forClass:(Class)aClass after:(SEL)sel perform:(SEL)callback;

@end
#endif
#endif
