//
//  Xtrace.mm
//  Xtrace
//
//  Created by John Holdsworth on 28/02/2014.
//  Copyright (c) 2014 John Holdsworth. All rights reserved.
//
//  Repo: https://github.com/johnno1962/Xtrace
//
//  $Id: //depot/Xtrace/Xray/Xtrace.mm#16 $
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

#define ARGS_SUPPORTED 20

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

static BOOL includeProperties, hideReturns, showArguments, describeValues;
static id delegate;

+ (void)setDelegate:aDelegate {
    delegate = aDelegate;
}

+ (void)hideReturns:(BOOL)hide {
    hideReturns = hide;
}

+ (void)includeProperties:(BOOL)include {
    includeProperties = include;
}

+ (void)showArguments:(BOOL)show {
    showArguments = show;
#ifdef __LP64__
    NSLog( @"Xtrace: ** Argument logging not reliable with 64bit apps **" );
#endif
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

static regex_t *methodFilter;

+ (void)methodFilter:(const char *)pattern {
    methodFilter = new regex_t;
    int error = regcomp(methodFilter, pattern, REG_ENHANCED);
    if ( error ) {
        char errbuff[PATH_MAX];
        regerror( error, methodFilter, errbuff, sizeof errbuff );
        NSLog( @"Xtrace: Filter compilation error: %s, in pattern: \"%s\"", errbuff, pattern );
        delete methodFilter;
        methodFilter = NULL;
    }
}

typedef void (*VIMP)( id obj, SEL sel, ... );

struct _arg {
    const char *name, *type;
    int stackOffset;
};

// information about original implementations
class original {
public:
    Method method;
    BOOL callingBack;
    VIMP before, original, after;
    const char *name, *type, *mtype;
#ifdef ARGS_SUPPORTED
    struct _arg args[ARGS_SUPPORTED];
#endif
    void *lastObj;
    BOOL wasObj( void *thisObj ) {
        return lastObj && thisObj == lastObj;
    }
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
    if ( ![self intercept:aClass method:class_getInstanceMethod(aClass, sel) mtype:NULL] ||
        !(originals[aClass][sel].before = (VIMP)[delegate methodForSelector:callback]) )
        NSLog( @"Xtrace: ** Could not setup callback for: [%s %s]", class_getName(aClass), sel_getName(sel) );
}

+ (void)forClass:(Class)aClass after:(SEL)sel callback:(SEL)callback {
    if ( ![self intercept:aClass method:class_getInstanceMethod(aClass, sel) mtype:NULL] ||
        !(originals[aClass][sel].after = (VIMP)[delegate methodForSelector:callback]) )
        NSLog( @"Xtrace: ** Could not setup callback for: [%s %s]", class_getName(aClass), sel_getName(sel) );
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


static BOOL describing;

static NSString *formatValue( const char *type, void *valptr ) {
    switch ( type[0] == 'r' ? type[1] : type[0] ) {
        case 'B':
            return [NSString stringWithFormat:@"%d", *(bool *)valptr];
        case 'c':
            return [NSString stringWithFormat:@"%d", *(char *)valptr];
        case 'C':
            return [NSString stringWithFormat:@"%u", *(unsigned char *)valptr];
        case 's':
            return [NSString stringWithFormat:@"%d", *(short *)valptr];
        case 'S':
            return [NSString stringWithFormat:@"%u", *(unsigned short *)valptr];
        case 'i':
            return [NSString stringWithFormat:@"%d", *(int *)valptr];
        case 'I':
            return [NSString stringWithFormat:@"%u", *(unsigned int *)valptr];
        case 'q':
#ifndef __LP64__
            return [NSString stringWithFormat:@"%lldLL", *(long long *)valptr];
#endif
        case 'l':
            return [NSString stringWithFormat:@"%ldL", *(long *)valptr];
        case 'Q':
#ifndef __LP64__
            return [NSString stringWithFormat:@"%lluLL", *(unsigned long long *)valptr];
#endif
        case 'L':
            return [NSString stringWithFormat:@"%luL", *(unsigned long *)valptr];
        case 'f':
            return [NSString stringWithFormat:@"%f", *(float *)valptr];
        case 'd':
            return [NSString stringWithFormat:@"%f", *(double *)valptr];
        case ':':
            return [NSString stringWithFormat:@"@selector(%s)", sel_getName(*(SEL *)valptr)];
        case '*':
            return [NSString stringWithFormat:@"\"%.100s\"", *(char **)valptr];
        case '^':
            return [NSString stringWithFormat:@"%p", *(void **)valptr];
        case '#': case '@': {
            id obj = *(const id *)valptr;
            describing = YES;
            NSString *desc = describeValues ? [obj description] :
                [NSString stringWithFormat:@"<%s %p>", class_getName(object_getClass(obj)), obj];
            describing = NO;
            return desc;
        }
        case '{':
            // structs printed back-to-front on stack //
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
            if ( strncmp(type,"{CGRect=",8) == 0 )
                return NSStringFromCGRect( *(CGRect *)valptr );
            else if ( strncmp(type,"{CGPoint=",9) == 0 )
                return NSStringFromCGPoint( *(CGPoint *)valptr );
            else if ( strncmp(type,"{CGSize=",8) == 0 )
                return NSStringFromCGSize( *(CGSize *)valptr );
            else if ( strncmp(type,"{CGAffineTransform=",19) == 0 )
                return NSStringFromCGAffineTransform( *(CGAffineTransform *)valptr );
#else
            if ( strncmp(type,"{_NSRect=",9) == 0 || strncmp(type,"{CGRect=",8) == 0 )
                return NSStringFromRect( *(NSRect *)valptr );
            else if ( strncmp(type,"{_NSPoint=",10) == 0 || strncmp(type,"{CGPoint=",9) == 0 )
                return NSStringFromPoint( *(NSPoint *)valptr );
            else if ( strncmp(type,"{_NSSize=",9) == 0 || strncmp(type,"{CGSize=",8) == 0 )
                return NSStringFromSize( *(NSSize *)valptr );
#endif
            else if ( strncmp(type,"{_NSRange=",10) == 0 )
                return NSStringFromRange( *(NSRange *)valptr );
    }

    return @"<??>";
}

#define ARG_SIZE sizeof(id) + sizeof(SEL) + sizeof(void *)*9 // something may be aligned
#define ARG_DEFS void *a0, void *a1, void *a2, void *a3, void *a4, void *a5, void *a6, void *a7, void *a8, void *a9
#define ARG_COPY a0, a1, a2, a3, a4, a5, a6, a7, a8, a9

// necessary to catch messages to [super ...]
static BOOL hasSuper( Class aClass, SEL sel ) {
    while ( (aClass = class_getSuperclass( aClass )) )
        if ( originals[aClass].find(sel) != originals[aClass].end() )
            return YES;
    return NO;
}

// find original implmentation for message and log call
static original &findOriginal( id obj, SEL sel, ARG_DEFS ) {
    void *thisObj = XTRACE_BRIDGE(void *)obj;
    Class aClass = object_getClass(obj);

    while ( (aClass && originals[aClass].find(sel) == originals[aClass].end())
           || (originals[aClass][sel].wasObj( thisObj ) && hasSuper(aClass, sel)) )
        aClass = class_getSuperclass( aClass );

    original &orig = originals[aClass][sel];
    orig.lastObj = thisObj;

    // add custom filtering of logging here..
    if ( !describing && orig.mtype &&
        (!useTargets || targets.find(orig.lastObj) != targets.end()) ) {
        NSMutableString *args = [NSMutableString string];

        if ( !showArguments )
            [args appendFormat:@" %s", orig.name];
        else {
            const char *frame = (char *)(void *)&obj+sizeof obj;

            for ( struct _arg *aptr = orig.args ; *aptr->name ; aptr++ ) {
                [args appendFormat:@" %.*s", (int)(aptr[1].name-aptr->name), aptr->name];
                if ( !aptr->type )
                    break;

                NSString *val = formatValue(aptr->type, (void *)(frame-aptr[1].stackOffset) );
                [args appendString:val];
            }
        }

        NSLog( @"%*s%s[<%s %p>%@] %s", indent++, "", orig.mtype,
              class_getName(object_getClass(obj)), obj, args, orig.type );
    }

    return orig;
}

// log returning value
static void returning( original &orig, void *valptr ) {
    indent && indent--;

    if ( valptr && !hideReturns && !describing && orig.mtype &&
        (!useTargets || targets.find(orig.lastObj) != targets.end()) ) {
        NSString *val = formatValue(orig.type, valptr);
        NSLog( @"%*s-> %@ (%s)", indent, "", val, orig.name );
    }

    orig.lastObj = NULL;
}

// replacement implmentations "swizzled" into place
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

    returning( orig, NULL );
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

    returning( orig, &out );
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
             (!methodFilter || regexec(methodFilter, name, 0, NULL, 0) != REG_NOMATCH) ) {

        original &orig = originals[aClass][sel];

        orig.name = name;
        orig.type = type;
        orig.mtype = mtype;
        orig.method = method;

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

// break up selector into args
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

// parse method encoding into stack offsets
+ (int)extractOffsets:(const char *)type into:(struct _arg *)args {
    int frameLen = -1;

    for ( int i=0 ; i<ARGS_SUPPORTED ; i++ ) {
        args->type = type;
        while ( !isdigit(*type) )
            type++;
        args->stackOffset = atoi(type);
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

@end
#endif
