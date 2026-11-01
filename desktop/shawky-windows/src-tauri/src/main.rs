// Shawky WhatsApp for Windows: a WebView2 window on web.shawkygroup.com that also handles the
// CRM's shawkywhatsapp://launch?session=... links. No local pages and no IPC: the site runs as in
// a browser, with only its own origin allowed inside the window.
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod links;

use tauri::menu::{Menu, MenuItem};
use tauri::tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent};
use tauri::webview::NewWindowResponse;
use tauri::{AppHandle, Manager, Url, WebviewUrl, WebviewWindowBuilder, WindowEvent};
use tauri_plugin_opener::OpenerExt;

const MAIN: &str = "main";

fn main() {
    tauri::Builder::default()
        // Must be first: a second launch (CRM button while the app is open) hands its link to this one.
        .plugin(tauri_plugin_single_instance::init(|app, args, _cwd| {
            let target = links::deep_link_from_args(&args).and_then(|link| links::launch_url_from(link, &links::app_url()));
            show(app, target);
        }))
        .plugin(tauri_plugin_deep_link::init())
        .plugin(tauri_plugin_opener::init())
        .setup(|app| {
            let app_url = links::app_url();
            let args: Vec<String> = std::env::args().collect();
            let start = links::deep_link_from_args(&args)
                .and_then(|link| links::launch_url_from(link, &app_url))
                .unwrap_or_else(|| app_url.clone());
            build_window(app.handle(), start, app_url)?;
            build_tray(app.handle())?;
            Ok(())
        })
        // Closing hides to the tray so new-message notifications keep arriving.
        .on_window_event(|window, event| {
            if let WindowEvent::CloseRequested { api, .. } = event {
                api.prevent_close();
                let _ = window.hide();
            }
        })
        .run(tauri::generate_context!())
        .expect("error while running Shawky WhatsApp");
}

fn build_window(app: &AppHandle, start: Url, app_url: Url) -> tauri::Result<()> {
    let nav_app = app.clone();
    let nav_origin = app_url.clone();
    let popup_app = app.clone();
    WebviewWindowBuilder::new(app, MAIN, WebviewUrl::External(start))
        .title("Shawky WhatsApp")
        .inner_size(1280.0, 820.0)
        .min_inner_size(900.0, 600.0)
        // Only the Shawky WhatsApp site loads inside the app; other links open in the default browser.
        .on_navigation(move |url| {
            if links::is_app_url(url, &nav_origin) {
                return true;
            }
            open_external(&nav_app, url);
            false
        })
        .on_new_window(move |url, _features| {
            open_external(&popup_app, &url);
            NewWindowResponse::Deny
        })
        .build()?;
    Ok(())
}

fn build_tray(app: &AppHandle) -> tauri::Result<()> {
    let open = MenuItem::with_id(app, "open", "فتح Shawky WhatsApp", true, None::<&str>)?;
    let quit = MenuItem::with_id(app, "quit", "خروج", true, None::<&str>)?;
    TrayIconBuilder::new()
        .icon(app.default_window_icon().cloned().expect("bundle icon is configured"))
        .tooltip("Shawky WhatsApp")
        .menu(&Menu::with_items(app, &[&open, &quit])?)
        .show_menu_on_left_click(false)
        .on_menu_event(|app, event| match event.id().as_ref() {
            "open" => show(app, None),
            "quit" => app.exit(0),
            _ => {}
        })
        .on_tray_icon_event(|tray, event| {
            if let TrayIconEvent::Click { button: MouseButton::Left, button_state: MouseButtonState::Up, .. } = event {
                show(tray.app_handle(), None);
            }
        })
        .build(app)?;
    Ok(())
}

fn show(app: &AppHandle, target: Option<Url>) {
    let Some(window) = app.get_webview_window(MAIN) else { return };
    if let Some(url) = target {
        let _ = window.navigate(url);
    }
    let _ = window.unminimize();
    let _ = window.show();
    let _ = window.set_focus();
}

fn open_external(app: &AppHandle, url: &Url) {
    if matches!(url.scheme(), "http" | "https" | "mailto" | "tel") {
        let _ = app.opener().open_url(url.as_str(), None::<&str>);
    }
}
