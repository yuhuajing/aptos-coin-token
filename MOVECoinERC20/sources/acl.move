/// ACL has both an allow list and a deny list
/// 1) If one address is in the deny list, it is denied
/// 2) If the allow list is empty and not in the deny list, it is allowed
/// 3) If one address is in the allow list and not in the deny list, it is allowed
/// 4) If the allow list is not empty and the address is not in the allow list, it is denied
module ClayCoin::acl {
    use std::vector;
    use std::error;

    const ELAYERZERO_ACCESS_DENIED: u64 = 0;

    struct ACL has store, drop {
        allow_list: vector<address>,
        deny_list: vector<address>,
    }

    public fun empty(): ACL {
        ACL {
            allow_list: vector::empty<address>(),
            deny_list: vector::empty<address>(),
        }
    }

    /// if not in the allow list, add it. Otherwise, remove it.
    public fun allowlist(acl: &mut ACL, addr: address) {
        let (found, index) = vector::index_of(&acl.allow_list, &addr);
        if (found) {
            vector::swap_remove(&mut acl.allow_list, index);
        } else {
            vector::push_back(&mut acl.allow_list, addr);
        };
    }

    /// if not in the deny list, add it. Otherwise, remove it.
    public fun denylist(acl: &mut ACL, addr: address) {
        let (found, index) = vector::index_of(&acl.deny_list, &addr);
        if (found) {
            vector::swap_remove(&mut acl.deny_list, index);
        } else {
            vector::push_back(&mut acl.deny_list, addr);
        };
    }

    public fun allowlist_contains(acl: &ACL, addr: &address): bool {
        vector::contains(&acl.allow_list, addr)
    }

    public fun denylist_contains(acl: &ACL, addr: &address): bool {
        vector::contains(&acl.deny_list, addr)
    }

// not in the deny list.
//allowlist is empty || allowlist is not empty and this address is in the allowlist
    public fun is_allowed(acl: &ACL, addr: &address): bool {
        if (vector::contains(&acl.deny_list, addr)) {
            return false
        };

        vector::length(&acl.allow_list) == 0
            || vector::contains(&acl.allow_list, addr)
    }

    public fun assert_allowed(acl: &ACL, addr:& address) {
        assert!(is_allowed(acl, addr), error::permission_denied(ELAYERZERO_ACCESS_DENIED));
    }
}