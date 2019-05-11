import std.stdio;
import x11.X;
import x11.Xlib;
import std.string;
import std.array;
import std.algorithm;
import std.traits;
import core.thread;
import std.random;
import std.datetime;
import std.conv;
import std.functional;
import uranium;

///Wrapper for draw text functionality
class Text: Component {
  mixin(defProps!("string msg;"));

  this(Props* props) {
    this.props = props;
  }

  override void draw(Node* node) {
    auto drawInfo = cast(XWindow.WindowChildDrawInfo*)node.drawInfo;
    writeln(*drawInfo);
    XDrawString(drawInfo.display, drawInfo.window, DefaultGC(drawInfo.display, drawInfo.screen), drawInfo.x, drawInfo.y+10, cast(char*)this.props.msg, cast(int)this.props.msg.length);
  }
}

class Button: Component {
  EventMonitor.UnsubscribeEvent buttonPressSubscription;
  int bb_x;
  int bb_y;
  int bb_xx;
  int bb_yy;

  mixin(defProps!("string msg; void delegate() onClick;"));
  this(Props* props) {
    this.props = props;
  }

  void onButtonPress(XEvent e, Display* display, Window window) {
    if (e.xbutton.x > bb_x && e.xbutton.y > bb_y && e.xbutton.x < bb_xx && e.xbutton.y < bb_yy) {
      if (props.onClick) {
        props.onClick();
      }
    }
  }

  override void draw(Node* node) {
    auto drawInfo = cast(XWindow.WindowChildDrawInfo*)node.drawInfo;
    if (buttonPressSubscription is null) {
      buttonPressSubscription = drawInfo.monitor.subscribe(cast(EventTypes)ButtonPress, &onButtonPress);
    }
    bb_x = drawInfo.x;
    bb_y = drawInfo.y;
    bb_xx = drawInfo.x+drawInfo.width;
    bb_yy = drawInfo.y+drawInfo.height;

    XSetForeground(drawInfo.display, DefaultGC(drawInfo.display, drawInfo.screen), WhitePixel(drawInfo.display, drawInfo.screen));
    XFillRectangle(drawInfo.display, drawInfo.window, DefaultGC(drawInfo.display, drawInfo.screen), drawInfo.x, drawInfo.y, drawInfo.width, drawInfo.height);
    XSetForeground(drawInfo.display, DefaultGC(drawInfo.display, drawInfo.screen), BlackPixel(drawInfo.display, drawInfo.screen));

    XDrawString(drawInfo.display, drawInfo.window, DefaultGC(drawInfo.display, drawInfo.screen), drawInfo.x, drawInfo.y+10, cast(char*)this.props.msg, cast(int)this.props.msg.length);
    XDrawRectangle(drawInfo.display, drawInfo.window, DefaultGC(drawInfo.display, drawInfo.screen), drawInfo.x, drawInfo.y, drawInfo.width, drawInfo.height);
  }

  ~this() {
    buttonPressSubscription.unsubscribe();
  }
}

enum KeyCodes {
  Backspace = 22,
  LeftArrow = 113,
  RightArrow = 114,
  Delete = 119
}
//Input box
class TextInput: Component {
  int bb_x;
  int bb_y;
  int bb_xx;
  int bb_yy;

  EventMonitor.UnsubscribeEvent buttonPressSubscription;
  EventMonitor.UnsubscribeEvent keypressSubscription;
  EventMonitor.UnsubscribeEvent exposeSubscription;
  bool updateDrawn = true;
  mixin(defProps!(""));
  mixin(defState!("char[] coreStr = []; int pos = 0; bool active = false;"));

  this(Props* props) {
    this.props = props;
    this.state = new State();
  }

  void onKeyPress(XEvent e, Display* display, Window window) {
    if (active) {
      switch (e.xkey.keycode) {
        case KeyCodes.Backspace: {
          coreStr = coreStr[0..max(pos - 1, 0)] ~ coreStr[pos..coreStr.length];
          pos = max(pos - 1, 0);
          break;
        }

        case KeyCodes.LeftArrow: {
          pos = max(pos - 1, 0);
          break;
        }
        case KeyCodes.RightArrow: {
          pos = min(pos + 1, coreStr.length);
          break;
        }

        case KeyCodes.Delete: {
          coreStr = coreStr[0..pos] ~ coreStr[min(pos + 1, coreStr.length)..coreStr.length];
          break;
        }

        default: {
          auto chr = cast(char)XKeycodeToKeysym(display, cast(ubyte)e.xkey.keycode, 0);
          coreStr = coreStr[0..pos] ~ chr ~ coreStr[pos..coreStr.length];
          pos = pos = min(pos + 1, coreStr.length+1);
        }
      }
    }
  }
  void onExpose(XEvent e, Display* display, Window window) {
    updateDrawn = true;
  }

  void onButtonPress(XEvent e, Display* display, Window window) {
    active = e.xbutton.x > bb_x && e.xbutton.y > bb_y && e.xbutton.x < bb_xx && e.xbutton.y < bb_yy;
  }

  override void draw(Node* node) {
    auto drawInfo = cast(XWindow.WindowChildDrawInfo*)node.drawInfo;
    if (keypressSubscription is null) {
      keypressSubscription = drawInfo.monitor.subscribe(cast(EventTypes)KeyPress, &onKeyPress);
    }
    if (exposeSubscription is null) {
      exposeSubscription = drawInfo.monitor.subscribe(cast(EventTypes)Expose, &onExpose);
    }
    if (buttonPressSubscription is null) {
      buttonPressSubscription = drawInfo.monitor.subscribe(cast(EventTypes)ButtonPress, &onButtonPress);
    }
    bb_x = drawInfo.x;
    bb_y = drawInfo.y;
    bb_xx = drawInfo.x+drawInfo.width;
    bb_yy = drawInfo.y+drawInfo.height;

    if (updateDrawn) {
      XSetForeground(drawInfo.display, DefaultGC(drawInfo.display, drawInfo.screen), WhitePixel(drawInfo.display, drawInfo.screen));
      XFillRectangle(drawInfo.display, drawInfo.window, DefaultGC(drawInfo.display, drawInfo.screen), drawInfo.x, drawInfo.y, drawInfo.width, drawInfo.height);
      XSetForeground(drawInfo.display, DefaultGC(drawInfo.display, drawInfo.screen), BlackPixel(drawInfo.display, drawInfo.screen));

      XDrawString(drawInfo.display, drawInfo.window, DefaultGC(drawInfo.display, drawInfo.screen), drawInfo.x, drawInfo.y+10, cast(char*)coreStr, cast(int)coreStr.length);
      auto length = XTextWidth(XLoadQueryFont(drawInfo.display, cast(char*)"*6x10*"), cast(char*)coreStr[0..pos], pos);
      if (active) {
        XDrawLine(drawInfo.display, drawInfo.window, DefaultGC(drawInfo.display, drawInfo.screen), drawInfo.x+length, drawInfo.y, drawInfo.x+length, drawInfo.y+10);
      }
      XDrawRectangle(drawInfo.display, drawInfo.window, DefaultGC(drawInfo.display, drawInfo.screen), drawInfo.x, drawInfo.y, drawInfo.width, drawInfo.height);
      updateDrawn = false;
    }
  }

  override Node*[] render() {
    updateDrawn = true;
    return null;
  }

  ~this() {
    keypressSubscription.unsubscribe();
    exposeSubscription.unsubscribe();
  }
}

///Vertical packing of children
class VBox: Component {
  mixin(defProps!(""));

  this(Props* props) {
    this.props = props;
  }

  override void draw(Node* node) {
    auto drawInfo = cast(XWindow.WindowChildDrawInfo*)node.drawInfo;
    auto incrementValue = drawInfo.height/node.renderedChildren.length;
    auto currentY = drawInfo.y;
    foreach (i; node.renderedChildren) {
      if (i !is null) {
        i.drawInfo = cast(DrawInfo*)new XWindow.WindowChildDrawInfo(drawInfo.drawInfo, drawInfo.display, drawInfo.window, drawInfo.screen, drawInfo.monitor, drawInfo.x, currentY, drawInfo.width, cast(int)(drawInfo.height/node.renderedChildren.length));
        i.draw();
        currentY += incrementValue;
      }
    }
  }

  override Node*[] render() {
    //What's up with this? Where did our children go?
    //And now they're back but corrupted
    //This looks like memory corruption
    //writeln(this.props.children);
    return this.props.children;
  }
}

///Horizontal packing of children
class HBox: Component {
  mixin(defProps!(""));

  this(Props* props) {
    this.props = props;
  }

  override void draw(Node* node) {
    auto drawInfo = cast(XWindow.WindowChildDrawInfo*)node.drawInfo;

    auto incrementValue = drawInfo.width/node.renderedChildren.length;
    auto currentX = drawInfo.x;
    foreach (i; node.renderedChildren) {
      if (i !is null) {
        i.drawInfo = cast(DrawInfo*)new XWindow.WindowChildDrawInfo(drawInfo.drawInfo, drawInfo.display, drawInfo.window, drawInfo.screen, drawInfo.monitor, currentX, drawInfo.y, cast(int)(drawInfo.width/node.renderedChildren.length), drawInfo.height);
        i.draw();
        currentX += incrementValue;
      }
		}
  }

  override Node*[] render() {
    return this.props.children;
  }
}

class XWindow: Component {
  Display *display;
  Window w;
  int screen;
  EventMonitor monitor;
  int width;
  int height;

  struct WindowChildDrawInfo {
    DrawInfo drawInfo;
    alias drawInfo this;
    Display *display;
    Window window;
    int screen;
    EventMonitor monitor;
    int x;
    int y;
    int width;
    int height;
  }

  mixin(defProps!("int width=640; int height=480;"));

  this(Props* props) {
    this.props = props;

    display = XOpenDisplay(null);
    if (display == null) {
      puts("Cannot open display");
      return;
    }

    width = props.width;
    height = props.height;
    screen = DefaultScreen(display);
    w = XCreateSimpleWindow(display, RootWindow(display, screen), 0, 0, width, height, 0, BlackPixel(display, screen), WhitePixel(display, screen));
    XSelectInput(display, w, AllEventsMask);
    XMapWindow(display, w);
    monitor = new EventMonitor(display, w);
  }

  override void draw(Node* node) {
    //XClearWindow(display, w);

    foreach (i; node.renderedChildren) {
      if (i !is null) {
        i.drawInfo = cast(DrawInfo*)new WindowChildDrawInfo(DrawInfo(), display, w, screen, monitor, 0, 0, width, height);
  			i.draw();
      }
		}
    monitor.poll();
  }

  override Node*[] render() {
    return this.props.children;
  }
}

const AllEventsMask = KeyPressMask | KeyReleaseMask | ButtonPressMask |
  ButtonReleaseMask | EnterWindowMask	| LeaveWindowMask | PointerMotionMask |
  PointerMotionHintMask | Button1MotionMask | Button2MotionMask |
  Button3MotionMask | Button4MotionMask | Button5MotionMask | ButtonMotionMask |
  KeymapStateMask | ExposureMask | VisibilityChangeMask | StructureNotifyMask |
  ResizeRedirectMask | SubstructureNotifyMask | SubstructureRedirectMask	|
  FocusChangeMask | PropertyChangeMask | ColormapChangeMask | OwnerGrabButtonMask;

enum EventTypes {
  KeyPress = 2,
  KeyRelease,
  ButtonPress,
  ButtonRelease,
  MotionNotify,
  EnterNotify,
  LeaveNotify,
  FocusIn,
  FocusOut,
  KeymapNotify,
  Expose,
  GraphicsExpose,
  NoExpose,
  VisibilityNotify,
  CreateNotify,
  DestroyNotify,
  UnmapNotify,
  MapNotify,
  MapRequest,
  ReparentNotify,
  ConfigureNotify,
  ConfigureRequest,
  GravityNotify,
  ResizeRequest,
  CirculateNotify,
  CirculateRequest,
  PropertyNotify,
  SelectionClear,
  SelectionRequest,
  SelectionNotify,
  ColormapNotify,
  ClientMessage,
  MappingNotify,
  GenericEvent
}

class EventMonitor {
  void delegate(XEvent e, Display* display, Window window)[int][EventTypes] subscriptions;
  Display* display;
  Window window;

  this(Display* display, Window window) {
    this.display = display;
    this.window = window;
  }

  void poll() {
    XEvent e;
    while (XCheckWindowEvent(display, window, AllEventsMask, &e)) {
      if (cast(EventTypes)e.type in subscriptions) {
        foreach (callback; subscriptions[cast(EventTypes)e.type]) {
          callback(e, display, window);
        }
      }
    }
  }

  UnsubscribeEvent subscribe(EventTypes type, void delegate(XEvent e, Display* display, Window window) callback) {
    auto key = uniform(0, int.max);
    subscriptions[type][key] = callback;
    return new UnsubscribeEvent(type, key);
  }

  class UnsubscribeEvent {
    EventTypes type;
    int key;
    this(EventTypes type, int key) {
      this.type = type;
      this.key = key;
    }

    void unsubscribe() {
      subscriptions[type].remove(key);
    }
  }
}

class Toggle: Component {
  mixin(defProps!(""));
  mixin(defState!("bool show_text = false;"));

  this(Props* props) {
    this.props = props;
    this.state = new State();
  }

  void toggleText() {
    show_text = !show_text;
  }

  override Node*[] render() {
    auto a = U!(Text, "Test");
    auto b = U!(VBox)(a);
    return [
      b
    ];
  }
}

void main()
{
  void test() {
    writeln("TEST");
  }
  auto onClick = toDelegate(&test);
  auto r = new Reactor();
  while (true) {
    auto startTime = MonoTime.currTime;
    r.render(
      U!(XWindow, 1280, 720)(
        U!(VBox)(
          //U!(Toggle),
          U!(Button, "Button1", onClick),
          U!(Button, "Button2"),
          U!(Button, "Button3"),
          U!(TextInput)
        )
      )
    );
    auto renderTime = MonoTime.currTime - startTime;
    Thread.sleep(dur!"msecs"(1000/30) - (renderTime));
  }
  //XCloseDisplay(display);
  //return 0;
}
