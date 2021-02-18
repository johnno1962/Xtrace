# ![Icon](http://injectionforxcode.johnholdsworth.com/stethoscope.gif)  Xtrace

Note: This project has been superseeded by the more rigourous [SwiftTrace](https://github.com/johnno1962/SwiftTrace).

### Trace Objective-C method calls by class or instance

Xtrace is a header Xtrace.h and a C++ implementation file Xtrace.mm that allows
you to intercept all method calls to instances of a class or a particular instance
giving you output such as this:

	   [<UILabel 0x8d4f170> setCenter:{240, 160}] v16@0:4{CGPoint=ff}8
		[<UILabel 0x8d4f170> actionForLayer:<CALayer 0x8d69410> forKey:<__NSCFString 0x8a535e0>] @16@0:4@8@12
		 [<UILabel 0x8d4f170> _shouldAnimatePropertyWithKey:<__NSCFString 0x8a535e0>] c12@0:4@8
		 -> 1 (_shouldAnimatePropertyWithKey:)
		-> <NSNull 0x194d068> (actionForLayer:forKey:)
	  [<UILabel 0x8d4f170> window] @8@0:4
	  -> <UIWindow 0x8a69920> (window)
	  [<UILabel 0x8d4f170> _isAncestorOfFirstResponder] c8@0:4
	  -> 0 (_isAncestorOfFirstResponder)
	 [<UILabel 0x8d4f170> layoutSublayersOfLayer:<CALayer 0x8d69410>] v12@0:4@8
	  [<UILabel 0x8d4f170> _viewControllerToNotifyOnLayoutSubviews] @8@0:4
	   [<UILabel 0x8d4f170> _viewDelegate] @8@0:4
	   -> <nil 0x0> (_viewDelegate)

To use, add Xtrace.{h,mm} to your project and add an import of Xtrace.h to your
project's ".pch" file so you can access its methods from anywhere in your project.
There is a simple category based shortcut interface to start tracing:

``` objc
	[MyClass xtrace]; // to trace all calls to instances of a class
	// this will intercept all methods of any superclasses as well
    // but only for instances of the class that has been traced (v2.1)
	
	[instance xtrace]; // to trace all calls to a particular instance.
	// multiple instances can by traced, use "notrace" to stop tracing
    // instance tracing takes precedence over class based filtering.

    [Xtrace traceBundleContainingClass:myClass];
    // trace your entire app's classes or those of an embedded framework
    
    [Xtrace traceClassPattern:@"^UI" excluding:nil]; // trace all of UIkit
```

If you have the [XcodeColors](https://github.com/johnno1962/XcodeColors) plugin
installed you can now color traces by selector, class or group of classes:

![Icon](http://injectionforxcode.johnholdsworth.com/xtracec.png?flush=2)

As an alternative to building Xtrace into your project, Xtrace is now included
in the "code injection" plugin from [injectionforxcode.com](http://injectionforxcode.com).
Once you have injected, all xtrace methods are available for you to use in lldb.

    (lldb) p [UITableView xtrace]

    // dump pseudo-header for class
    (lldb) p [UITableView xdump]
    @interface UITableView : UIScrollView {
        id<UITableViewDataSource> _dataSource; // @"<UITableViewDataSource>"
        UITableViewRowData * _rowData; // @"UITableViewRowData"
        float _rowHeight; // f
        float _sectionHeaderHeight; // f
        float _sectionFooterHeight; // f
        float _estimatedRowHeight; // f
        float _estimatedSectionHeaderHeight; // f
        float _estimatedSectionFooterHeight; // f
        CGRect _visibleBounds; // {CGRect="origin"{CGPoint="x"f"y"f}"size"{CGSize="width"f"height"f}}
    ...

The example project, originally called "Xray" will show you how to use the Xtrace module
to get up and running. Your milage will vary though the source should build and work for 
32 bit configurations on an iOS device or 64 bit OS X applications or the simulator. 
The starting point is the XRAppDelegate.m class. The XRDetailViewController.m then 
switches to instance viewing of a specific UILabel when the detail view loads.

Display of method arguments is now on by default, but if you have problems:

	[Xtrace showArguments:NO];

You can display the calling function on entry by setting:

    [Xtrace showCaller:YES];
	
You should also be able to switch to log the "description" of all values using:

	[Xtrace describeValues:YES];
	
Other features are a method name filtering regular expression. These filters
are applied as the class is "swizzled" when you request tracing.

	[Xtrace includeMethods:@"a|regular|expression"];
	[Xtrace excludeMethods:@"WithObjects:$"]; // varargs methods don't work
	[Xtrace excludeTypes:@"CGRect|CGSize"]; // stack frame problems on 64 bits
    [Xtrace excludeTypes:nil]; // reset filter after class is set up.
    
Classes can also be excluded (again before other classes are traced) by calling:

    [UIView notrace]; // or alternatively..
	[Xtrace dontTrace:[UIView class]];
    
A rudimentary profiling interface is also available:

    [Xtrace dumpProfile:100 dp:6]; // top 100 elapsed time to 6 decimal places
    
    1.318244/2    [UIApplication sendAction:to:from:forEvent:]
    0.725028/2    [UIWindow sendEvent:]
    0.706975/2    [UIWindow _sendTouchesForEvent:]
    0.701802/1    [UIControl touchesEnded:withEvent:]
    0.699627/2    [UIControl _sendActionsForEvents:withEvent:]
    0.659325/1    [UIControl sendAction:to:forEvent:]
    0.659292/1    [UIApplication sendAction:toTarget:fromSender:forEvent:]
    0.659204/1    [UIBarButtonItem _sendAction:withEvent:]
    0.659082/1    [UIViewController _toggleEditing:]
    0.659071/1    [UITableViewController setEditing:animated:]
    0.593577/53   [CALayer layoutSublayers]
    0.592025/53   [UIView layoutSublayersOfLayer:]
    ...

### Aspect oriented features

Finally, callbacks can also be registered on a delegate to be called before or after any method is called:

    [Xtrace setDelegate:delegate]; // delegate must not be traced itself
    [Xtrace forClass:[UILabel class] after:@selector(setText:) callback:@selector(label:setText:)];

    // void method signature for UILabel
    - (void)setText:(NSString *)text;

    // "before" and "after" callback implementation in delegate
    - (void)label:(id)receiver setText:(NSString *)text {
        ...
    }
    
Callbacks for specific methods can be used independently of full Class or instance tracing.
"after" callbacks for methods that return a value can replace the value returned to the caller
something like a variation on "aspect oriented programming".

    // non-void method signature in class "AClass"
    - (NSString *)appendString:(NSString *)string;

    // code to inject "after" method callback
    [Xtrace forClass:[AClass class] after:@selector(appendString:) callback:@selector(out:object:appendString:)];

    // "after" callback implementation in delegate
    - (NSString *)out:(NSString *)originalReturnValue object:(id)receiver appendString:(NSString *)string {
        ...
        return newReturnValue; // could be originalReturnValue
    }
    
The callback selector names are arbitrary. It's the order and type of arguments that is critical.
Expect some trouble passing structs on 64 bit builds. The signature for intercepting a "getter"
is a little contrived:

    // setup callback
    [Xtrace forClass:[UILabel class] after:@selector(text) callback:@selector(out:labelText:)];

    // implementation of callback
    - (NSString *)out:(NSString *)text labelText:(UILabel *)label {
        ...
        return text;
    }

There is also a block based api for callbacks which can be called at any time:

    [Xtrace forClass:[UIView class] before:@selector(sizeToFit) callbackBlock:^( UILabel *label ) {
        NSLog( @"%@ sizeToFit before: %@", label, NSStringFromCGRect(label.frame) );
    }];
    [Xtrace forClass:[UIView class] after:@selector(sizeToFit) callbackBlock:^( UILabel *label ) {
        NSLog( @"%@ sizeToFit after: %@", label, NSStringFromCGRect(label.frame) );
    }];

### What works:

![Icon](http://injectionforxcode.johnholdsworth.com/xtrace.png?flush=2)

Reliability is now quite good for 32 bit builds considering.. I've had to introduce
a method exclusion blacklist of a few methods causing problems. On 64 bit OS X
you can expect some stack frame complications for methods with "struct" argument 
or return types - in particular for arguments to callbacks to the delegate.
Xtrace does not currently work on the ARM64 abi - rebuild for 32 bits.

The ordering of calls to the api is: 1) Any class exclusions, 2) any method selector filter then
3) Class tracing or instance tracing and 4) any callbacks. That's about it. If you encounter 
problems drop me a line on xtrace (at) johnholdsworth.com. The developer of Xtrace and the
"Injection Plugin" is available for Cocoa/iOS development work in the London area.

Announcements of major commits to the repo will be made on twitter [@Injection4Xcode](https://twitter.com/#!/@Injection4Xcode).

### As ever:

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR 
PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE 
FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, 
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
