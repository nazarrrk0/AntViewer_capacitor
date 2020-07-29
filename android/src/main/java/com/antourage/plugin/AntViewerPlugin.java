package com.antourage.plugin;

import android.app.Activity;
import android.content.Intent;
import android.view.Gravity;
import android.view.ViewGroup;

import androidx.coordinatorlayout.widget.CoordinatorLayout;

import com.antourage.weaverlib.screens.base.AntourageActivity;
import com.antourage.weaverlib.ui.fab.AntourageFab;
import com.antourage.weaverlib.ui.fab.RegisterPushNotificationsResult;
import com.antourage.weaverlib.ui.fab.UserAuthResult;
import com.getcapacitor.JSObject;
import com.getcapacitor.NativePlugin;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;

import kotlin.Unit;
import kotlin.jvm.functions.Function1;

@NativePlugin()
public class AntViewerPlugin extends Plugin {
    private AntourageFab antFab;

    @PluginMethod()
    public void auth(PluginCall call) {
        String apiKey = call.getString("apiKey");

        if (apiKey == null || apiKey.isEmpty()) {
            call.reject("Must provide an apiKey");
            return;
        }

        String refUserId = call.getString("refUserId");
        String nickname = call.getString("nickname");

        this.getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if (antFab == null) {
                    antFab = new AntourageFab(getActivity());
                }

                antFab.authWith(apiKey, refUserId, nickname, result -> {
                    if (result instanceof UserAuthResult.Failure) {
                        call.reject(((UserAuthResult.Failure) result).getCause());
                    } else if (result instanceof UserAuthResult.Success) {
                        call.resolve();
                    }
                    return null;
                });
            }
        });
    }

    @PluginMethod()
    public void showFeedScreen(PluginCall call) {
        Intent intent = new Intent(getContext(), AntourageActivity.class);
        getActivity().startActivity(intent);
    }

    @PluginMethod()
    public void registerNotifications(PluginCall call) {
        String fcmToken = call.getString("fcmToken");

        if (fcmToken == null || fcmToken.isEmpty()) {
            call.reject("Must provide an fcmToken");
            return;
        }

        AntourageFab.Companion.registerNotifications(fcmToken, result -> {
            if (result instanceof RegisterPushNotificationsResult.Failure) {
                call.reject(((RegisterPushNotificationsResult.Failure) result).getCause());
            } else if (result instanceof RegisterPushNotificationsResult.Success) {
                JSObject json = new JSObject();
                json.put("topic", ((RegisterPushNotificationsResult.Success) result).getTopicName());
                call.resolve(json);
            }
            return null;
        });
    }


    @PluginMethod()
    public void showWidget(PluginCall call) {
        this.getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                Activity activity = getActivity();

                if (antFab == null) {
                    antFab = new AntourageFab(activity);
                }
                antFab.onResume();
                if (antFab.getParent() == null) {
                    ViewGroup viewGroup = (ViewGroup) ((ViewGroup) activity.findViewById(android.R.id.content)).getChildAt(0);

                    CoordinatorLayout.LayoutParams fabLayoutParams = new CoordinatorLayout.LayoutParams(
                            CoordinatorLayout.LayoutParams.WRAP_CONTENT,
                            CoordinatorLayout.LayoutParams.WRAP_CONTENT
                    );
                    fabLayoutParams.gravity = Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL ;

                    viewGroup.addView(antFab, fabLayoutParams);
                }
            }
        });
    }

    @PluginMethod()
    public void hideWidget(PluginCall call) {
        this.getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                Activity activity = getActivity();
                ViewGroup viewGroup = (ViewGroup) ((ViewGroup) activity.findViewById(android.R.id.content)).getChildAt(0);
                antFab.onPause();
                viewGroup.removeView(antFab);
            }
        });
    }
}