use std::{
    collections::HashMap,
    fs::{File, OpenOptions},
    sync::{Mutex, OnceLock},
};

use steel::{
    declare_module,
    steel_vm::ffi::{FFIModule, RegisterFFIFn},
};

// Keep each successfully locked File alive for as long as this process owns
// the lock. If Helix exits or is killed, the OS closes the descriptors and
// releases the locks automatically.
static LOCKS: OnceLock<Mutex<HashMap<String, File>>> = OnceLock::new();

fn locks() -> &'static Mutex<HashMap<String, File>> {
    LOCKS.get_or_init(|| Mutex::new(HashMap::new()))
}

fn try_acquire(path: String) -> bool {
    let mut locks = locks().lock().unwrap();

    // Do not allow re-entrant acquisition of the same lock in one process.
    if locks.contains_key(&path) {
        return false;
    }

    let file = match OpenOptions::new()
        .read(true)
        .write(true)
        .create(true)
        .open(&path)
    {
        Ok(file) => file,
        Err(_) => return false,
    };

    match file.try_lock() {
        Ok(()) => {
            locks.insert(path, file);
            true
        }
        Err(_) => false,
    }
}

fn release(path: String) -> bool {
    let mut locks = locks().lock().unwrap();

    match locks.remove(&path) {
        Some(file) => File::unlock(&file).is_ok(),
        None => false,
    }
}

declare_module!(create_module);

fn create_module() -> FFIModule {
    let mut module = FFIModule::new("cursor-history-lock");

    module.register_fn(
        "cursor-history-lock-try-acquire",
        try_acquire,
    );

    module.register_fn(
        "cursor-history-lock-release",
        release,
    );

    module
}
