module ModAddr::TaskId6 {
    friend ModAddr::Task6;

    use Std::Errors;
    use Std::Signer;

    const ETASK_ID_ADDRESS_SAME: u64 = 0;
    const ETASK_ID_INVALID_SIGNER: u64 = 1;

    struct TaskId has copy, drop, store {
        index: u128,
        publisher: address,
        performer: address
    }

    struct TaskIdCounter has key {
        counter: u128,
    }

    public(friend) fun initialize(account: &signer) {
        move_to(account, TaskIdCounter {
            counter: 0,
        });
    }

    public(friend) fun new(account: &signer, publisher: address, performer: address): TaskId acquires TaskIdCounter {
        assert_valid_arguments(account, publisher, performer);
        let store = borrow_global_mut<TaskIdCounter>(publisher);
        let task_index = store.counter;
        store.counter = task_index + 1;
        let task_id = TaskId {
            index: task_index,
            publisher,
            performer,
        };
        task_id
    }

    public(friend) fun get(account: &signer, publisher: address, performer: address, index: u128): TaskId {
        assert_valid_arguments(account, publisher, performer);
        let task_id = TaskId {
            index,
            publisher,
            performer,
        };
        task_id
    }

    public fun addresses_of(task_id: &TaskId): (address, address) {
        ((*task_id).publisher, (*task_id).performer)
    }

    public fun publisher(task_id: &TaskId): address {
        (*task_id).publisher
    }

    public fun performer(task_id: &TaskId): address {
        (*task_id).performer
    }

    fun assert_valid_arguments(account: &signer, publisher: address, performer: address) {
        assert!(publisher != performer, Errors::invalid_argument(ETASK_ID_ADDRESS_SAME));
        assert!(
            Signer::address_of(account) == publisher || Signer::address_of(account) == performer,
            Errors::invalid_argument(ETASK_ID_INVALID_SIGNER)
        );
    }
}
