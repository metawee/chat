//! Deep-link and navigation rules, kept free of Tauri so they are unit tested with `cargo test`.
use url::Url;

pub const PROTOCOL: &str = "shawkywhatsapp";
pub const DEFAULT_APP_URL: &str = "https://web.shawkygroup.com";

/// The dashboard this build opens. Override at build time with SHAWKY_APP_URL (e.g. staging).
pub fn app_url() -> Url {
    Url::parse(option_env!("SHAWKY_APP_URL").unwrap_or(DEFAULT_APP_URL)).expect("SHAWKY_APP_URL must be a valid URL")
}

/// Same format the server accepts (Shawky::LaunchesController::SESSION_FORMAT).
fn valid_session(session: &str) -> bool {
    session.len() >= 10
        && session.len() <= 130
        && session.starts_with("s_")
        && session[2..].chars().all(|c| c.is_ascii_alphanumeric() || c == '_' || c == '-')
}

/// shawkywhatsapp://launch?session=s_xxx -> https://web.shawkygroup.com/shawky/launch?session=s_xxx.
/// Anything else (other host, bad session) is ignored.
pub fn launch_url_from(deep_link: &str, app_url: &Url) -> Option<Url> {
    let link = Url::parse(deep_link).ok()?;
    if link.scheme() != PROTOCOL || link.host_str() != Some("launch") {
        return None;
    }
    let session = link.query_pairs().find(|(key, _)| key == "session")?.1.into_owned();
    if !valid_session(&session) {
        return None;
    }
    let mut target = app_url.join("/shawky/launch").ok()?;
    target.query_pairs_mut().append_pair("session", &session);
    Some(target)
}

/// On Windows the deep link arrives as a command-line argument.
pub fn deep_link_from_args(args: &[String]) -> Option<&str> {
    args.iter().map(String::as_str).find(|arg| arg.starts_with(&format!("{PROTOCOL}://")))
}

pub fn is_app_url(candidate: &Url, app_url: &Url) -> bool {
    candidate.origin() == app_url.origin()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn app() -> Url {
        Url::parse(DEFAULT_APP_URL).unwrap()
    }

    #[test]
    fn turns_the_crm_deep_link_into_the_launch_url() {
        let url = launch_url_from("shawkywhatsapp://launch?session=s_arZUC0VOUpqBfwQqO8ymgPZm", &app()).unwrap();
        assert_eq!(url.as_str(), "https://web.shawkygroup.com/shawky/launch?session=s_arZUC0VOUpqBfwQqO8ymgPZm");
    }

    #[test]
    fn ignores_other_hosts_bad_sessions_and_schemes() {
        for link in [
            "shawkywhatsapp://other?session=s_arZUC0VOUpqBfwQqO8ymgPZm",
            "shawkywhatsapp://launch?session=../../etc",
            "shawkywhatsapp://launch?session=s_short",
            "shawkywhatsapp://launch",
            "https://evil.example/launch?session=s_arZUC0VOUpqBfwQqO8ymgPZm",
            "not a url",
        ] {
            assert_eq!(launch_url_from(link, &app()), None, "{link}");
        }
    }

    #[test]
    fn finds_the_deep_link_among_arguments() {
        let args = vec![
            "C:\\Shawky WhatsApp.exe".to_string(),
            "shawkywhatsapp://launch?session=s_abcdefgh12".to_string(),
        ];
        assert_eq!(deep_link_from_args(&args), Some("shawkywhatsapp://launch?session=s_abcdefgh12"));
        assert_eq!(deep_link_from_args(&["app.exe".to_string()]), None);
    }

    #[test]
    fn keeps_navigation_inside_the_shawky_site() {
        let app = app();
        assert!(is_app_url(&Url::parse("https://web.shawkygroup.com/app/accounts/1/conversations/2").unwrap(), &app));
        assert!(!is_app_url(&Url::parse("https://web.shawkygroup.com.evil.example/").unwrap(), &app));
        assert!(!is_app_url(&Url::parse("https://system.shawkygroup.com/").unwrap(), &app));
    }
}
