Xtrace
======

Trace Objective-C method calls by class or instance

Xtrace is a header Xtrace.h and a C++ implementation file Xtrace.mm the allows
you to intercept all method calls to instances of a class or a particular instance.

To use, add Xtrace.{h,mm} to your project and add an import of Xtrace.h to your
project's .pch file so you can access it's methods from anywhere in your project.
There is a simple category based interface to start tracing:

	[MyClass xtrace]; // to trace all calls to instances of a class or..
	
	[instance xtrace]; // to trace all calls to a particular instance.
	
The example project, originally called "Xray" show you how to use the Xtrace module
to get you started. Your milage will vary though the source will build and work for 
most common configurations or OS X and iOS applications. If you are not using ARC
you can enable display of method arguments as follows:

	[Xtrace showArguments:YES];
	
Other features are a method name filter regular expression (which must be applied
before starting tracing:

	[Xtrace methodFilter:"a.*regular.*expression"];
	
Classes can be exclued (again before other classes are traced) by calling:

	[Xtrace dontTrace:[UIView class]];

If you encounter any problems drop me a line on xtrace (at) johnholdsworth.com

As ever:

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR 
PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE 
FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, 
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
