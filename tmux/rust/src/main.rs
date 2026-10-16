fn main() {
    let args: Result<Vec<String>, _> = std::env::args_os()
        .skip(1)
        .map(|s| s.into_string())
        .collect();
    let code = match args {
        Ok(args) if args.first().is_some_and(|s| s == "--panel-seat-exec") => {
            angelstar_runtime::panel_seat_entry(&args[1..])
        }
        Ok(args) if args.first().is_some_and(|s| s == "--delivery-producer") => {
            angelstar_runtime::producer_entry(&args[1..])
        }
        Ok(args) if args.len() >= 2 && args[0] == "--surface" => {
            angelstar_runtime::cli::main_entry(&args[1], &args[2..])
        }
        Ok(args) => {
            let name = std::env::args_os()
                .next()
                .and_then(|p| {
                    std::path::PathBuf::from(p)
                        .file_name()
                        .map(|n| n.to_string_lossy().into_owned())
                })
                .unwrap_or_default();
            angelstar_runtime::cli::main_entry(&name, &args)
        }
        _ => {
            eprintln!("relay: invalid argv or missing exact entry point");
            1
        }
    };
    std::process::exit(code);
}
