//
//  Xtrace.mm
//  Xtrace
//
//  Created by John Holdsworth on 28/02/2014.
//  Copyright (c) 2014 John Holdsworth. All rights reserved.
//
//  Repo: https://github.com/johnno1962/Xtrace
//
//  $Id: //depot/Xtrace/Xray/Xtrace.mm#26 $
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  Your milage will vary.. This is definitely a case of:
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
//  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
//  CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
//  TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
//  SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#ifdef DEBUG

#import "Xtrace.h"

#import <objc/runtime.h>
#import <map>

#ifdef __clang__
#if __has_feature(objc_arc)
#define XTRACE_ISARC
#endif
#endif

#ifdef XTRACE_ISARC
#define XTRACE_BRIDGE(_type) (__bridge _type)
#define XTRACE_RETAINED __attribute((ns_returns_retained))
#else
#define XTRACE_BRIDGE(_type) (_type)
#define XTRACE_RETAINED
#endif

#define ARGS_SUPPORTED 10

typedef void (*VIMP)( id obj, SEL sel, ... );

@implementation NSObject(Xtrace)

+ (void)notrace {
    [Xtrace dontTrace:self];
}

+ (void)xtrace {
    [Xtrace traceClass:self];
}

- (void)xtrace {
    [Xtrace traceInstance:self];
}

- (void)untrace {
    [Xtrace untrace:self];
}

@end

@implementation Xtrace

static BOOL includeProperties, hideReturns, showArguments, describeValues, logToDelegate;
static id delegate;

+ (void)setDelegate:aDelegate {
    delegate = aDelegate;
    logToDelegate = [delegate respondsToSelector:@selector(xtraceLog:)];
}

+ (void)hideReturns:(BOOL)hide {
    hideReturns = hide;
}

+ (void)includeProperties:(BOOL)include {
    includeProperties = include;
}

+ (void)showArguments:(BOOL)show {
    showArguments = show;
}

+ (void)describeValues:(BOOL)desc {
    describeValues = desc;
}

extern "C" {
    #include <regex.h>
}

#ifndef REG_ENHANCED
#define REG_ENHANCED 0
#endif

static regex_t *includeMethods, *excludeMethods;

+ (regex_t *)methodFilter:(const char *)pattern {
    regex_t *methodFilter = new regex_t;
    int error = regcomp(methodFilter, pattern, REG_ENHANCED);
    if ( error ) {
        char errbuff[PATH_MAX];
        regerror( error, methodFilter, errbuff, sizeof errbuff );
        NSLog( @"Xtrace: Filter compilation error: %s, in pattern: \"%s\"", errbuff, pattern );
        delete methodFilter;
        methodFilter = NULL;
    }
    return methodFilter;
}

+ (BOOL)includeMethods:(const char *)pattern {
    return (includeMethods = [self methodFilter:pattern]) != NULL;
}

+ (BOOL)excludeMethods:(const char *)pattern {
    return (excludeMethods = [self methodFilter:pattern]) != NULL;
}

struct _arg {
    const char *name, *type;
    int stackOffset;
};

// information about original implementations
class original {
public:
    Method method;
    VIMP before, original, after;
    const char *name, *type, *mtype;
    struct _arg args[ARGS_SUPPORTED+1];

    void *lastObj;
    BOOL wasObj( void *thisObj ) {
        return lastObj && thisObj == lastObj;
    }

    struct _stats stats;
    BOOL callingBack;
};

static std::map<Class,std::map<SEL,original> > originals;
static std::map<Class,BOOL> excludedClasses;
static std::map<void *,BOOL> targets;
static BOOL useTargets;
static int indent;

+ (void)dontTrace:(Class)aClass {
    Class metaClass = object_getClass(aClass);
    excludedClasses[metaClass] = 1;
    excludedClasses[aClass] = 1;
}

+ (void)traceClass:(Class)aClass {
    [self traceClass:aClass levels:100];
}

+ (void)traceClass:(Class)aClass levels:(int)levels {
    Class metaClass = object_getClass(aClass);
    [self traceClass:metaClass mtype:"+" levels:levels];
    [self traceClass:aClass mtype:"" levels:levels];
}

+ (void)traceInstance:(id)instance {
    targets[XTRACE_BRIDGE(void *)instance] = 1;
    [self traceClass:[instance class]];
    useTargets = YES;
}

+ (void)untrace:(id)instance {
    auto i = targets.find(XTRACE_BRIDGE(void *)instance);
    if ( i != targets.end() )
        targets.erase(i);
}

+ (void)forClass:(Class)aClass before:(SEL)sel callback:(SEL)callback {
    if ( !(originals[aClass][sel].before = [self forClass:aClass intercept:sel callback:callback]) )
        NSLog( @"Xtrace: ** Could not setup before callback for: [%s %s]", class_getName(aClass), sel_getName(sel) );
}

+ (void)forClass:(Class)aClass replace:(SEL)sel callback:(SEL)callback {
    if ( !(originals[aClass][sel].original = [self forClass:aClass intercept:sel callback:callback]) )
        NSLog( @"Xtrace: ** Could not setup replace callback for: [%s %s]", class_getName(aClass), sel_getName(sel) );
}

+ (void)forClass:(Class)aClass after:(SEL)sel callback:(SEL)callback {
    if ( !(originals[aClass][sel].after = [self forClass:aClass intercept:sel callback:callback]) )
        NSLog( @"Xtrace: ** Could not setup after callback for: [%s %s]", class_getName(aClass), sel_getName(sel) );
}

+ (VIMP)forClass:(Class)aClass intercept:(SEL)sel callback:(SEL)callback {
    return [self intercept:aClass method:class_getInstanceMethod(aClass, sel) mtype:NULL] ?
        (VIMP)[delegate methodForSelector:callback] : NULL;
}

+ (void)traceClass:(Class)aClass mtype:(const char *)mtype levels:(int)levels {
    for ( int l=0 ; l<levels ; l++ ) {

        if ( excludedClasses.find(aClass) == excludedClasses.end() ) {
            unsigned mc = 0;
            Method *methods = class_copyMethodList(aClass, &mc);

            for( int i=0; methods && i<mc; i++ )
                [self intercept:aClass method:methods[i] mtype:mtype];

            free( methods );
        }

        aClass = class_getSuperclass(aClass);
        if ( aClass == [NSObject class] || aClass == object_getClass([NSObject class]) )
            break;
    }
}

+ (struct _stats *)statsFor:(Class)aClass sel:(SEL)sel {
    return &originals[aClass][sel].stats;
}

// delegate can implement as instance method
+ (void)xtraceLog:(NSString *)trace {
    printf( "| %s\n", [trace UTF8String] );
}

static BOOL describing;

#define APPEND_TYPE( _enc, _fmt, _type ) case _enc: [args appendFormat:_fmt, va_arg(*argp,_type)]; return YES;

static BOOL formatValue( const char *type, void *valptr, va_list *argp, NSMutableString *args ) {
    switch ( type[0] == 'r' ? type[1] : type[0] ) {
        case 'V': case 'v':
            return NO;
#if 0
        case 'B':
        case 'C': case 'c':
        case 'S': case 's':
#else
        // warnings here necessary evil
        APPEND_TYPE( 'B', @"%d", BOOL )
        APPEND_TYPE( 'c', @"%d", char )
        APPEND_TYPE( 'C', @"%d", unsigned char )
        APPEND_TYPE( 's', @"%d", short )
        APPEND_TYPE( 'S', @"%d", unsigned short )
#endif
        APPEND_TYPE( 'i', @"%d", int )
        APPEND_TYPE( 'I', @"%u", unsigned )
        APPEND_TYPE( 'f', @"%f", float )
        APPEND_TYPE( 'd', @"%f", double )
        APPEND_TYPE( '^', @"%p", void * )
        APPEND_TYPE( '*', @"\"%.100s\"", char * )
#ifndef __LP64__
        APPEND_TYPE( 'q', @"%lldLL", long long )
#else
        case 'q':
#endif
        APPEND_TYPE( 'l', @"%ldL", long )
#ifndef __LP64__
        APPEND_TYPE( 'Q', @"%lluLL", unsigned long long )
#else
        case 'Q':
#endif
        APPEND_TYPE( 'L', @"%luL", unsigned long )
        case ':':
            [args appendFormat:@"@selector(%s)", sel_getName(va_arg(*argp,SEL))];
            return YES;
        case '#': case '@': {
            id obj = va_arg(*argp,id);
            if ( describeValues ) {
                describing = YES;
                [args appendString:obj?[obj description]:@"<nil>"];
                describing = NO;
            }
            else
                [args appendFormat:@"<%s %p>", class_getName(object_getClass(obj)), obj];
            return YES;
        }
        case '{':
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
            if ( strncmp(type,"{CGRect=",8) == 0 )
                [args appendString:NSStringFromCGRect( va_arg(*argp,CGRect) )];
            else if ( strncmp(type,"{CGPoint=",9) == 0 )
                [args appendString:NSStringFromCGPoint( va_arg(*argp,CGPoint) )];
            else if ( strncmp(type,"{CGSize=",8) == 0 )
                [args appendString:NSStringFromCGSize( va_arg(*argp,CGSize) )];
            else if ( strncmp(type,"{CGAffineTransform=",19) == 0 )
                [args appendString:NSStringFromCGAffineTransform( va_arg(*argp,CGAffineTransform) )];
            else if ( strncmp(type,"{UIEdgeInsets=",14) == 0 )
                [args appendString:NSStringFromUIEdgeInsets( va_arg(*argp,UIEdgeInsets) )];
            else if ( strncmp(type,"{UIOffset=",10) == 0 )
                [args appendString:NSStringFromUIOffset( va_arg(*argp,UIOffset) )];
#else
            if ( strncmp(type,"{_NSRect=",9) == 0 || strncmp(type,"{CGRect=",8) == 0 )
                [args appendString:NSStringFromRect( va_arg(*argp,NSRect) )];
            else if ( strncmp(type,"{_NSPoint=",10) == 0 || strncmp(type,"{CGPoint=",9) == 0 )
                [args appendString:NSStringFromPoint( va_arg(*argp,NSPoint) )];
            else if ( strncmp(type,"{_NSSize=",9) == 0 || strncmp(type,"{CGSize=",8) == 0 )
                [args appendString:NSStringFromSize( va_arg(*argp,NSSize) )];
#endif
            else if ( strncmp(type,"{_NSRange=",10) == 0 )
                [args appendString:NSStringFromRange( va_arg(*argp,NSRange) )];
            else
                break;
            return YES;
    }

    [args appendString:@"<??>"];
    return YES;
}

// necessary to catch messages to [super ...]
static BOOL hasSuper( Class aClass, SEL sel ) {
    while ( (aClass = class_getSuperclass( aClass )) )
        if ( originals[aClass].find(sel) != originals[aClass].end() )
            return YES;
    return NO;
}

// find original implmentation for message and log call
static original &findOriginal( id obj, SEL sel, ... ) {
    va_list argp; va_start(argp, sel);
    Class aClass = object_getClass(obj);
    void *thisObj = XTRACE_BRIDGE(void *)obj;

    while ( (aClass && originals[aClass].find(sel) == originals[aClass].end())
           || (originals[aClass][sel].wasObj( thisObj ) && hasSuper(aClass, sel)) )
        aClass = class_getSuperclass( aClass );

    original &orig = originals[aClass][sel];

    orig.lastObj = thisObj;
    orig.stats.callCount++;
    orig.stats.entered = [NSDate timeIntervalSinceReferenceDate];

    if ( !describing && orig.mtype &&
        (!useTargets || targets.find(orig.lastObj) != targets.end()) ) {
        NSMutableString *args = [NSMutableString string];
        [args appendFormat:@"%*s%s[<%s %p>", indent++, "",
         orig.mtype, class_getName(object_getClass(obj)), obj];

        if ( !showArguments )
            [args appendFormat:@" %s", orig.name];
        else {
            const char *frame = (char *)(void *)&obj+sizeof obj;
            void *valptr = &sel;

            for ( struct _arg *aptr = orig.args ; *aptr->name ; aptr++ ) {
                [args appendFormat:@" %.*s", (int)(aptr[1].name-aptr->name), aptr->name];
                if ( !aptr->type )
                    break;

                valptr = (void *)(frame+aptr[1].stackOffset);
                formatValue( aptr->type, valptr, &argp, args );
            }
        }

        // add custom filtering of logging here..
        [args appendFormat:@"] %s %p", orig.type, orig.original];
        [logToDelegate ? delegate : [Xtrace class] xtraceLog:args];
    }

    return orig;
}

// log returning value
static void returning( original &orig, ... ) {
    va_list argp; va_start(argp, orig);
    indent && indent--;

    if ( /*valptr &&*/ !hideReturns && !describing && orig.mtype &&
        (!useTargets || targets.find(orig.lastObj) != targets.end()) ) {
        NSMutableString *val = [NSMutableString string];
        [val appendFormat:@"%*s-> ", indent, ""];
        if ( formatValue(orig.type, NULL, &argp, val) ) {
            [val appendFormat:@" (%s)", orig.name];
            [logToDelegate ? delegate : [Xtrace class] xtraceLog:val];
        }
    }

    orig.stats.elapsed = [NSDate timeIntervalSinceReferenceDate] - orig.stats.entered;
    orig.lastObj = NULL;
}

#define ARG_SIZE sizeof(id) + sizeof(SEL) + sizeof(void *)*9 // something may be aligned
#define ARG_DEFS void *a0, void *a1, void *a2, void *a3, void *a4, void *a5, void *a6, void *a7, void *a8, void *a9
#define ARG_COPY a0, a1, a2, a3, a4, a5, a6, a7, a8, a9

// replacement implmentations "swizzled" onto class
static void vimpl( id obj, SEL sel, ARG_DEFS ) {
    original &orig = findOriginal(obj, sel, ARG_COPY);

    if ( orig.before && !orig.callingBack ) {
        orig.callingBack = YES;
        orig.before( delegate, sel, obj, ARG_COPY );
        orig.callingBack = NO;
    }

    orig.original( obj, sel, ARG_COPY );

    if ( orig.after && !orig.callingBack ) {
        orig.callingBack = YES;
        orig.after( delegate, sel, obj, ARG_COPY );
        orig.callingBack = NO;
    }

    returning( orig );
}

template <typename _type>
static _type XTRACE_RETAINED intercept( id obj, SEL sel, ARG_DEFS ) {
    original &orig = findOriginal(obj, sel, ARG_COPY);

    if ( orig.before && !orig.callingBack ) {
        orig.callingBack = YES;
        orig.before( delegate, sel, obj, ARG_COPY );
        orig.callingBack = NO;
    }

    _type (*impl)( id obj, SEL sel, ... ) = (_type (*)( id obj, SEL sel, ... ))orig.original;
    _type out = impl( obj, sel, ARG_COPY );

    if ( orig.after && !orig.callingBack ) {
        orig.callingBack = YES;
        impl = (_type (*)( id obj, SEL sel, ... ))orig.after;
        out = impl( delegate, sel, out, obj, ARG_COPY );
        orig.callingBack = NO;
    }

    returning( orig, out );
    return out;
}

+ (BOOL)intercept:(Class)aClass method:(Method)method mtype:(const char *)mtype {
    SEL sel = method_getName(method);
    const char *name = sel_getName(sel);
    const char *className = class_getName(aClass);
    const char *type = method_getTypeEncoding(method);

    //NSLog( @"%s %s %s %s", mtype, className, name, type );

    IMP newImpl = NULL;
    switch ( type[0] == 'r' ? type[1] : type[0] ) {
        case 'V':
        case 'v': newImpl = (IMP)vimpl; break;
        case 'B': newImpl = (IMP)intercept<bool>; break;
        case 'C':
        case 'c': newImpl = (IMP)intercept<char>; break;
        case 'S':
        case 's': newImpl = (IMP)intercept<short>; break;
        case 'I':
        case 'i': newImpl = (IMP)intercept<int>; break;
        case 'Q':
        case 'q':
#ifndef __LP64__
            newImpl = (IMP)intercept<long long>; break;
#endif
        case 'L':
        case 'l': newImpl = (IMP)intercept<long>; break;
        case 'f': newImpl = (IMP)intercept<float>; break;
        case 'd': newImpl = (IMP)intercept<double>; break;
        case '#':
        case '@': newImpl = (IMP)intercept<id>; break;
        case '^': newImpl = (IMP)intercept<void *>; break;
        case ':': newImpl = (IMP)intercept<SEL>; break;
        case '*': newImpl = (IMP)intercept<char *>; break;
        case '{':
            if ( strncmp(type,"{_NSRange=",10) == 0 )
                newImpl = (IMP)intercept<NSRange>;
#ifndef __IPHONE_OS_VERSION_MIN_REQUIRED
            else if ( strncmp(type,"{_NSRect=",9) == 0 )
                newImpl = (IMP)intercept<NSRect>;
            else if ( strncmp(type,"{_NSPoint=",10) == 0 )
                newImpl = (IMP)intercept<NSPoint>;
            else if ( strncmp(type,"{_NSSize=",9) == 0 )
                newImpl = (IMP)intercept<NSSize>;
#endif
            else if ( strncmp(type,"{CGRect=",8) == 0 )
                newImpl = (IMP)intercept<CGRect>;
            else if ( strncmp(type,"{CGPoint=",9) == 0 )
                newImpl = (IMP)intercept<CGPoint>;
            else if ( strncmp(type,"{CGSize=",8) == 0 )
                newImpl = (IMP)intercept<CGSize>;
            else if ( strncmp(type,"{CGAffineTransform=",19) == 0 )
                newImpl = (IMP)intercept<CGAffineTransform>;
            break;
        default:
            NSLog(@"Xtrace: Unsupported return type: %s for: %s[%s %s]", type, mtype, className, name);
    }

    const char *frameSize = type+1;
    while ( !isdigit(*frameSize) )
        frameSize++;

    if ( atoi(frameSize) > ARG_SIZE )
        NSLog( @"Xtrace: Stack frame too large to trace method: %s[%s %s]",
              mtype, className, name );
    else if ( newImpl && name[0] != '.' &&
             strcmp(name,"retain") != 0 && strcmp(name,"release") != 0 &&
             strcmp(name,"dealloc") != 0 && strcmp(name,"description") != 0 &&
             (includeProperties || !mtype || !class_getProperty( aClass, name )) &&
             (!includeMethods || regexec(includeMethods, name, 0, NULL, 0) != REG_NOMATCH) &&
             (!excludeMethods || regexec(excludeMethods, name, 0, NULL, 0) == REG_NOMATCH) ) {

        original &orig = originals[aClass][sel];

        orig.name = name;
        orig.type = type;
        orig.method = method;
        if ( mtype )
            orig.mtype = mtype;

        [self extractSelector:name into:orig.args];
        [self extractOffsets:type into:orig.args];

        IMP impl = method_getImplementation(method);
        if ( impl != newImpl ) {
            orig.original = (VIMP)impl;
            method_setImplementation(method,newImpl);
        }

        return YES;
    }

    return NO;
}

// break up selector by argument
+ (int)extractSelector:(const char *)name into:(struct _arg *)args {

    for ( int i=0 ; i<ARGS_SUPPORTED ; i++ ) {
        args->name = name;
        const char *next = index( name, ':' );
        if ( next ) {
            name = next+1;
            args++;
        }
        else {
            args[1].name = name+strlen(name);
            return i;
        }
    }

    return -1;
}

// parse method encoding for call stack offsets (replaced by varargs)

#if 1 // original version using information in method type encoding

+ (int)extractOffsets:(const char *)type into:(struct _arg *)args {
    int frameLen = -1;

    for ( int i=0 ; i<ARGS_SUPPORTED ; i++ ) {
        args->type = type;
        while ( !isdigit(*type) )
            type++;
        args->stackOffset = -atoi(type);
        if ( i==0 )
            frameLen = args->stackOffset;
        while ( isdigit(*type) )
            type++;
        if ( i>2 )
            args++;
        else
            args->type = NULL;
        if ( !*type ) {
            args->stackOffset = frameLen;
            return i;
        }
    }

    return -1;
}

#else // alternate less robust "NSGetSizeAndAlignment()" version

+ (int)extractOffsets:(const char *)type into:(struct _arg *)args {
    NSUInteger size, align, offset = 0;

    type = NSGetSizeAndAlignment( type, &size, &align );

    for ( int i=0 ; i<ARGS_SUPPORTED ; i++ ) {
        while ( isdigit(*type) )
            type++;
        args->type = type;
        type = NSGetSizeAndAlignment( type, &size, &align );
        if ( !*type )
            return i;
        offset -= size;
        offset &= ~(align-1 | sizeof(void *)-1);
        args[1].stackOffset = (int)offset;
        if ( i>1 )
            args++;
        else
            args->type = NULL;
    }

    return -1;
}

#endif
@end
#endif
