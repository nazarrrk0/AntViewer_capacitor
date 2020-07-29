#import <Foundation/Foundation.h>
#import <Capacitor/Capacitor.h>

// Define the plugin using the CAP_PLUGIN Macro, and
// each method the plugin supports using the CAP_PLUGIN_METHOD macro.
CAP_PLUGIN(AntViewerPlugin, "AntViewerPlugin",
					 CAP_PLUGIN_METHOD(registerNotifications, CAPPluginReturnPromise);
					 CAP_PLUGIN_METHOD(showFeedScreen, CAPPluginReturnPromise);
					 CAP_PLUGIN_METHOD(auth, CAPPluginReturnPromise);
					 CAP_PLUGIN_METHOD(showWidget, CAPPluginReturnPromise);
					 CAP_PLUGIN_METHOD(hideWidget, CAPPluginReturnPromise);
)
