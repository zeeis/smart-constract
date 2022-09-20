module ModAddr::Task7 {
    use Std::ASCII;
    use Std::Errors;
    use Std::Signer;

    use ModAddr::TaskId7::{Self, TaskId};
    use ModAddr::TaskStore7;
    use ModAddr::TaskEvent7;

    const ETASK: u64 = 0;

    const TS_PUBLISHED: u8 = 0;
    const TS_CANCELED: u8 = 1;
    const TS_ACCEPTED: u8 = 2;
    const TS_ABANDONED: u8 = 3;
    const TS_UNCONFIRM: u8 = 4;
    const TS_SUCCEEDED: u8 = 5;
    const TS_FAILED: u8 = 6;

    public fun assert_initialized<TaskType: store>(addr: address) {
        assert!(TaskStore7::is_initialized<TaskType>(addr), Errors::not_published(ETASK));
    }

    public fun initialize<TaskType: store>(account: &signer) {
        // assert not initialize
        let addr = Signer::address_of(account);
        assert!(!TaskStore7::is_initialized<TaskType>(addr), Errors::already_published(ETASK));

        TaskId7::initialize(account);
        TaskEvent7::initialize(account);
        TaskStore7::initialize<TaskType>(account);
    }

    public fun task_publish<TaskType: store>(
        publisher: &signer,
        performer_addr: address,
        data: TaskType,
        meta_bytes: vector<u8>
    ): TaskId {
        let publisher_addr = Signer::address_of(publisher);
        assert_initialized<TaskType>(publisher_addr);
        assert_initialized<TaskType>(performer_addr);

        let meta_data = ASCII::string(meta_bytes);
        let task_id = TaskId7::new(publisher, publisher_addr, performer_addr);
        TaskStore7::task_add<TaskType>(task_id, data, meta_data);
        TaskEvent7::emit_task_create(&task_id);
        task_id
    }

    public fun task_change_state<TaskType: store>(
        task_id: &TaskId,
        from: u8,
        to: u8,
        disabled: bool
    ) {
        let (publisher, performer) = TaskId7::addresses_of(task_id);
        assert_initialized<TaskType>(publisher);
        assert_initialized<TaskType>(performer);

        TaskStore7::task_change_state<TaskType>(task_id, from, to, disabled);
        TaskEvent7::emit_task_state_change(task_id, from, to);
    }

    public fun get_task_id_from_publisher(account: &signer, performer: address, index: u128): TaskId {
        let publisher = Signer::address_of(account);
        TaskId7::get(account, publisher, performer, index)
    }

    public fun get_task_id_from_performer(account: &signer, publisher: address, index: u128): TaskId {
        let performer = Signer::address_of(account);
        TaskId7::get(account, publisher, performer, index)
    }

    public fun task_state<TaskType: store>(task_id: &TaskId): u8 {
        TaskStore7::task_state<TaskType>(task_id)
    }

    public fun task_data<TaskType: copy + store>(task_id: &TaskId): TaskType {
        TaskStore7::task_data<TaskType>(task_id)
    }

    public fun assert_task_exists<TaskType: store>(task_id: &TaskId) {
        TaskStore7::assert_task_contains<TaskType>(task_id);
    }
}
