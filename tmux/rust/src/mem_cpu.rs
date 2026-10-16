use std::time::Duration;

unsafe extern "C" {
    fn mach_host_self() -> libc::host_t;
    static mach_task_self_: libc::mach_port_t;
    fn mach_port_deallocate(
        task: libc::mach_port_t,
        name: libc::mach_port_t,
    ) -> libc::kern_return_t;
}

struct Host(libc::host_t);
impl Drop for Host {
    fn drop(&mut self) {
        unsafe {
            mach_port_deallocate(mach_task_self_, self.0);
        }
    }
}
fn ticks(host: libc::host_t) -> Option<[u32; 4]> {
    let mut info: libc::host_cpu_load_info = unsafe { std::mem::zeroed() };
    let mut count = libc::HOST_CPU_LOAD_INFO_COUNT;
    let status = unsafe {
        libc::host_statistics(
            host,
            libc::HOST_CPU_LOAD_INFO,
            (&mut info as *mut libc::host_cpu_load_info).cast(),
            &mut count,
        )
    };
    (status == libc::KERN_SUCCESS && count == libc::HOST_CPU_LOAD_INFO_COUNT)
        .then_some(info.cpu_ticks)
}
fn cpu(before: [u32; 4], after: [u32; 4]) -> Option<f64> {
    let delta = std::array::from_fn::<_, 4, _>(|i| u64::from(after[i].wrapping_sub(before[i])));
    let total: u64 = delta.iter().sum();
    (total != 0)
        .then(|| 100.0 * (total - delta[libc::CPU_STATE_IDLE as usize]) as f64 / total as f64)
}
fn ram(total: u64, page: u64, free: u32, file_backed: u32) -> Option<String> {
    if total == 0
        || !(1024..=1048576).contains(&page)
        || !page.is_power_of_two()
        || total as f64 / 1073741824.0 > 9999.9
    {
        return None;
    }
    let excluded = (u64::from(free) + u64::from(file_backed)).checked_mul(page)?;
    let used = total.checked_sub(excluded)?;
    Some(format!(
        "{:.1}G/{:.1}G",
        used as f64 / 1073741824.0,
        total as f64 / 1073741824.0
    ))
}
fn memory(host: libc::host_t) -> Option<String> {
    let mut total = 0u64;
    let mut size = std::mem::size_of_val(&total);
    if unsafe {
        libc::sysctlbyname(
            c"hw.memsize".as_ptr(),
            (&mut total as *mut u64).cast(),
            &mut size,
            std::ptr::null_mut(),
            0,
        )
    } != 0
        || size != std::mem::size_of_val(&total)
    {
        return None;
    }
    let page = u64::try_from(unsafe { libc::sysconf(libc::_SC_PAGESIZE) }).ok()?;
    let mut info: libc::vm_statistics64 = unsafe { std::mem::zeroed() };
    let mut count = libc::HOST_VM_INFO64_COUNT;
    let needed = ((std::mem::offset_of!(libc::vm_statistics64, external_page_count)
        + std::mem::size_of::<u32>())
        / std::mem::size_of::<libc::integer_t>()) as u32;
    if unsafe {
        libc::host_statistics64(
            host,
            libc::HOST_VM_INFO64,
            (&mut info as *mut libc::vm_statistics64).cast(),
            &mut count,
        )
    } != libc::KERN_SUCCESS
        || count < needed
    {
        return None;
    }
    ram(total, page, info.free_count, info.external_page_count)
}
pub fn entry(args: &[String]) -> i32 {
    if !args.is_empty() {
        eprintln!("usage: mem-cpu");
        return 2;
    }
    let host = Host(unsafe { mach_host_self() });
    let cpu = ticks(host.0)
        .and_then(|before| {
            std::thread::sleep(Duration::from_secs(1));
            cpu(before, ticks(host.0)?)
        })
        .map(|value| format!("{value:.0}"))
        .unwrap_or_else(|| "?".into());
    let ram = memory(host.0).unwrap_or_else(|| "?G/?G".into());
    println!("CPU {cpu}% · RAM {ram}");
    0
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn cpu_interval_preserves_counter_wrap_and_zero_fallback() {
        assert_eq!(cpu([100, 20, u32::MAX - 2, 0], [110, 25, 2, 0]), Some(75.0));
        assert_eq!(cpu([0; 4], [0; 4]), None);
    }
    #[test]
    fn ram_matches_non_file_backed_gib_and_rejects_invalid_samples() {
        assert_eq!(
            ram(8 << 30, 4096, 131072, 393216).as_deref(),
            Some("6.0G/8.0G")
        );
        assert_eq!(ram(4096, 4096, 2, 0), None);
        assert_eq!(ram(8 << 30, 3000, 0, 0), None);
    }
}
