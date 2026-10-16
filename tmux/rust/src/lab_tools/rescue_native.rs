use std::ffi::CStr;

unsafe extern "C" {
    fn proc_pidpath(pid: i32, buffer: *mut libc::c_void, size: u32) -> i32;
}

pub(super) fn path(pid: u32) -> Option<String> {
    let mut b = [0u8; 4096];
    if unsafe { proc_pidpath(pid as i32, b.as_mut_ptr().cast(), b.len() as u32) } <= 0 {
        return None;
    }
    Some(
        unsafe { CStr::from_ptr(b.as_ptr().cast()) }
            .to_string_lossy()
            .into_owned(),
    )
}
#[cfg(test)]
pub(super) fn process_args(pid: u32) -> Option<Vec<String>> {
    let mut mib = [libc::CTL_KERN, 49, pid as i32];
    let mut size = 0;
    if unsafe {
        libc::sysctl(
            mib.as_mut_ptr(),
            3,
            std::ptr::null_mut(),
            &mut size,
            std::ptr::null_mut(),
            0,
        )
    } != 0
        || size < 5
    {
        return None;
    }
    let mut bytes = vec![0u8; size];
    if unsafe {
        libc::sysctl(
            mib.as_mut_ptr(),
            3,
            bytes.as_mut_ptr().cast(),
            &mut size,
            std::ptr::null_mut(),
            0,
        )
    } != 0
    {
        return None;
    }
    bytes.truncate(size);
    let argc = i32::from_ne_bytes(bytes[..4].try_into().ok()?);
    if !(1..=4096).contains(&argc) {
        return None;
    }
    let mut pos = 4 + bytes[4..].iter().position(|b| *b == 0)?;
    while bytes.get(pos) == Some(&0) {
        pos += 1;
    }
    let mut args = Vec::new();
    for _ in 0..argc {
        let end = pos + bytes.get(pos..)?.iter().position(|b| *b == 0)?;
        args.push(String::from_utf8(bytes[pos..end].to_vec()).ok()?);
        pos = end + 1;
    }
    Some(args)
}
pub(super) fn process_start(pid: u32) -> String {
    let Some(p) = crate::identity::kernel_process(pid) else {
        return String::new();
    };
    let seconds = p.start_seconds as libc::time_t;
    let mut tm = unsafe { std::mem::zeroed() };
    let mut bytes = [0u8; 64];
    unsafe {
        libc::localtime_r(&seconds, &mut tm);
        libc::strftime(
            bytes.as_mut_ptr().cast(),
            bytes.len(),
            c"%a %b %e %T %Y".as_ptr(),
            &tm,
        );
        CStr::from_ptr(bytes.as_ptr().cast())
            .to_string_lossy()
            .split_whitespace()
            .collect::<Vec<_>>()
            .join(" ")
    }
}
