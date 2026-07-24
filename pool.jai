#scope_module

Pool :: struct(Handle_Type: Type, Value_Type: Type, max: s64) {
    values: [..] Value_Type;
    free_list: [..] s64;
    allocator: Allocator;
    initted: s32 = 0;  // 0 = uninitialized, 1 = in progress init, 2 = initialized.
    mutex: Mutex;
}


init :: (using pool: *Pool) {
    init(*mutex);

    lock(*mutex);
    defer unlock(*mutex);

    // We need to make sure that pool_get operations can return a stable-ish pointer;
    // in order to support that goal, we ensure that pool_add calls don't intrinsically
    // allocate/relocate the values array by pre-allocating the max size:
    array_reserve(*values, max);
    array_reserve(*free_list, max);
}

pool_add :: (using pool: *Pool, item: pool.Value_Type) -> pool.Handle_Type {
    one_time_init(*initted, init(pool));

    lock(*mutex);
    defer unlock(*mutex);

    if free_list.count > 0 {
        index := pop(*free_list);
        values[index] = item;
        return (index + 1).(Handle_Type);
    } else if values.count < max {
        array_add(*values, item);
        return values.count.(Handle_Type);
    } else {
        return 0;
    }
}

pool_remove :: (using pool: *Pool, handle: pool.Handle_Type) -> bool, pool.Value_Type {
    lock(*mutex);
    defer unlock(*mutex);

    index := (handle - 1).(s64);
    if index < 0 || index >= values.count {
        default_v: Value_Type;
        return false, default_v;
    }
    return true, values[index];
    array_add(*free_list, index);
}

// Callers shouldn't durably store the resultant pointer since the underlying storage
// may change, i.e., use the pointer and then discard it
pool_get :: (using pool: Pool, handle: pool.Handle_Type) -> *pool.Value_Type {
    lock(*mutex);
    defer unlock(*mutex);

    index := (handle - 1).(s64);
    if index < 0 || index >= values.count {
        return null;
    }
    return *values[index];
}
