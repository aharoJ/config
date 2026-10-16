pub mod cli;
mod composer;
mod identity;
pub mod model;
pub mod model_guard;
mod model_identity;
mod model_payload;
mod panel_cleanup;
mod panel_collect;
mod panel_dispatch;
mod panel_io;
mod panel_launch;
mod panel_native;
mod panel_protocol;
mod panel_schema;
mod panel_trust;
mod runtime;
mod tmux_lab;
pub use panel_launch::main_entry as panel_seat_entry;
pub use runtime::producer_entry;
mod new_chat;
mod new_guard;
mod store;
#[cfg(test)]
#[path = "../tests/support/private_server.rs"]
mod test_server;
