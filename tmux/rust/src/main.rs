fn main() {
    let args: Result<Vec<String>, _> = std::env::args_os()
        .skip(1)
        .map(|s| s.into_string())
        .collect();
    let code = match args {
        Ok(args) if args.len() >= 2 && args[0] == "--surface" => {
            angelstar_runtime::cli::main_entry(&args[1], &args[2..])
        }
        _ => {
            eprintln!("relay: invalid argv or missing exact entry point");
            1
        }
    };
    std::process::exit(code);
}
