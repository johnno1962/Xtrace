# ![Icon](http://injectionforxcode.johnholdsworth.com/stethoscope.gif)  Xtrace

Trace Objective-C method calls by class or instance

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
project's ".pch" file so you can access it's methods from anywhere in your project.
There is a simple category based shortcut interface to start tracing:

	[MyClass xtrace]; // to trace all calls to instances of a class
	// this will intercet all methods of any superclasses as well
	
	[instance xtrace]; // to trace all calls to a particular instance.
	// multiple instances can by traced, use "notrace" to stop tracing
    // instance tracing takes precedence over class based filtering.
	
The example project, originally called "Xray" will show you how to use the Xtrace module
to get up and running. Your milage will vary though the source should build and work for 
most common configurations of OS X and iOS applications. The starting point is the
XRAppDelegate.m class. The XRDetailViewController.m then switches to instance viewing
of a specific UILabel when the detail view loads.

If you are not using ARC you can enable display of method arguments as follows:

	[Xtrace showArguments:YES];
	
You should be able to switch to log the "description" of all values using:

	[Xtrace describeValues:YES];
	
Other features are a method name filtering regular expression (which must be set
before starting any tracing):

	[Xtrace methodFilter:"a|regular|expression"];
	
Classes can also be excluded (again before other classes are traced) by calling:

    [UIView notrace]; // or alternatively..
	[Xtrace dontTrace:[UIView class]];
    
A few exmaple combos:

    // trace UI label instance excluding UIView methods
    [UIView notrace];
    [label xtrace];
    
    // trace two instances
    [label trace];
    [view trace];

    // stop tracing them
    [view untrace];
    [label untrace];

That's about it. If you encounter problems drop me a line on xtrace (at) johnholdsworth.com

As ever:

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR 
PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE 
FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, 
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
