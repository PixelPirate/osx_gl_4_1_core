//
//  main.m
//
//  Created by Patrick Horlebein on 27.12.14.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <objc/objc-runtime.h>
#import <OpenGL/OpenGL.h>

#define GL_VERSION 0x1F02
const GLubyte *glGetString(GLenum name);

typedef struct DelegateState {
    BOOL is_closed;
    void *context;
    void *view;
    void (*handler)(uint, uint);
} DelegateState;

id timer_did_fire(id self, SEL _cmd, id sender);
id window_should_close(id self, SEL _cmd);
id window_did_resize(id self, SEL _cmd);

static id delegateObject = nil;

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        [NSApp finishLaunching];
        
        NSRect frame = NSMakeRect(0.0f, 0.0f, 1024.0f, 768.0f);
        NSUInteger masks = NSTitledWindowMask |
                           NSClosableWindowMask |
                           NSMiniaturizableWindowMask |
                           NSResizableWindowMask;
        NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                       styleMask:masks
                                                         backing:NSBackingStoreBuffered
                                                           defer:NO];
        [window setTitle:@"Untitled"];
        [window setAcceptsMouseMovedEvents:YES];
        [window center];
        
        NSView *view = [[NSView alloc] init];
        [view setWantsBestResolutionOpenGLSurface:YES];
        [window setContentView:view];
        NSOpenGLPixelFormatAttribute attributes[] = {
            NSOpenGLPFADoubleBuffer,
            NSOpenGLPFAClosestPolicy,
            NSOpenGLPFAColorSize, 24,
            NSOpenGLPFAAlphaSize, 8,
            NSOpenGLPFADepthSize, 24,
            NSOpenGLPFAStencilSize, 8,
            NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion4_1Core,
            0
        };
        
        uint32 *attr = (uint32 *)attributes;
        NSMutableString *s = [NSMutableString stringWithString:@"["];
        while (*attr != 0) {
            [s appendFormat:@"%d", *attr];
            if (*(attr+1) != 0) {
                [s appendString:@", "];
            }
            ++attr;
        }
        [s appendString:@"]"];
        NSLog(@"%@", s);
        
        NSOpenGLPixelFormat *pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
        NSOpenGLContext *context = [[NSOpenGLContext alloc] initWithFormat:pixelFormat shareContext:nil];
        [context setView:view];
        GLint vsync = 1;
        [context setValues:&vsync forParameter:NSOpenGLCPSwapInterval];
        [context makeCurrentContext];
        [NSApp activateIgnoringOtherApps:YES];
        [window makeKeyAndOrderFront:nil];
        
        Class delegate = objc_allocateClassPair([NSObject class], "Delegate", 0);
        {
            class_addMethod(delegate, @selector(windowShouldClose:), (IMP)window_should_close, "B@:@");
            class_addMethod(delegate, @selector(windowDidResize:), (IMP)window_did_resize, "V@:@");
            class_addIvar(delegate, "glutin_state", sizeof(int), 3, "?");
            objc_registerClassPair(delegate);
            delegateObject = [[delegate alloc] init];
        }
        [window setDelegate:delegateObject];
        
        SEL timerDidFireSEL = sel_registerName("timerDidFire:");
        id timerDelegateObject;
        {
            Class timerDelegate = objc_allocateClassPair([NSObject class], "TimerDelegate", 0);
            class_addMethod(timerDelegate, timerDidFireSEL, (IMP)timer_did_fire, "V@:@");
            objc_registerClassPair(timerDelegate);
            timerDelegateObject = [[timerDelegate alloc] init];
        }
        NSTimer *timer = [[NSTimer alloc] initWithFireDate:[NSDate date]
                                                  interval:0.0166f
                                                    target:timerDelegateObject
                                                  selector:timerDidFireSEL
                                                  userInfo:nil
                                                   repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
        [NSApp run];
    }
    return 0;
}

id timer_did_fire(id self, SEL _cmd, id sender) {
    const GLubyte *version = glGetString(GL_VERSION);
    NSLog(@"%s", version);
    return nil;
}

id window_should_close(id self, SEL _cmd) {
    void *state;
    NSValue *extracted = [delegateObject valueForKey:@"glutin_state"];
    [extracted getValue:&state];
    DelegateState *s = (DelegateState *)state;
    s->is_closed = YES;
    return nil;
}

id window_did_resize(id self, SEL _cmd) {
    void *state;
    NSValue *extracted = [delegateObject valueForKey:@"glutin_state"];
    [extracted getValue:&state];
    DelegateState *s = (DelegateState *)state;
    [((__bridge id)s->context) update];
    if (s->handler != nil) {
        NSRect frame = [((__bridge NSView *)s->view) frame];
        s->handler(frame.size.width, frame.size.height);
    }
    return nil;
}
