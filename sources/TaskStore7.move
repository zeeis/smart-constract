module ModAddr::TaskStore7 {
    friend ModAddr::Task7;

    use Std::ASCII;
//    use Std::Vector;
    use Std::Errors;
    use AptosFramework::Table::{Self, Table};
    use ModAddr::TaskId7::{Self, TaskId};

    const ETASK_ID_DUPLICATED: u64 = 1;
    const ETASK_ID_NOT_FOUND: u64 = 2;
    const ETASK_STATE_NOT_ENABLED: u64 = 4;
    const ETASK_STATE_NOT_MATCHED: u64 = 5;

    struct TaskHolder<TaskType: store> has store {
        id: TaskId,
        state: u8,
        data: TaskType,
        meta_data: ASCII::String,
    }

    struct TaskStore<TaskType: store> has key {
        task_table: Table<TaskId, TaskHolder<TaskType>>,
    }

//    struct TaskEnabled<phantom TaskType> has key {
//        task_id_list: vector<TaskId>,
//    }
//
//    struct TaskDisabled<phantom TaskType> has key {
//        task_id_list: vector<TaskId>,
//    }

    public(friend) fun is_initialized<TaskType: store>(addr: address): bool {
        exists<TaskStore<TaskType>>(addr)
    }

    public(friend) fun initialize<TaskType: store>(account: &signer) {
//        move_to(account, TaskEnabled<TaskType> {
//            task_id_list: Vector::empty(),
//        });
//        move_to(account, TaskDisabled<TaskType> {
//            task_id_list: Vector::empty(),
//        });
        move_to(account, TaskStore<TaskType> {
            task_table: Table::new<TaskId, TaskHolder<TaskType>>(),
        });
    }

    public(friend) fun task_add<TaskType: store>(task_id: TaskId, data: TaskType, meta_data: ASCII::String)
    acquires TaskStore/*, TaskEnabled*/ {
        let publisher = TaskId7::publisher(&task_id);
        let task_table = &mut borrow_global_mut<TaskStore<TaskType>>(publisher).task_table;
        // assert not contains
        assert!(!Table::contains(task_table, task_id), Errors::internal(ETASK_ID_DUPLICATED));
        Table::add(task_table, copy task_id, TaskHolder<TaskType> {
            id: task_id,
            state: 0u8, // TS_PUBLISHED: u8 = 0;
            data,
            meta_data,
        });
//        on_task_add<TaskType>(&task_id);
    }

    public(friend) fun task_change_state<TaskType: store>(task_id: &TaskId, from: u8, to: u8, disable: bool)
    acquires TaskStore/*, TaskEnabled, TaskDisabled*/ {
        // assert contains
        assert_task_contains<TaskType>(task_id);
        // assert enabled then return list_index
//        let (list_index_1, list_index_2) = assert_task_enabled<TaskType>(task_id, Errors::invalid_argument(ETASK_STATE_NOT_ENABLED));

        // ----->> remove from enabled
//        if (disable) {
//            remove_enabled<TaskType>(task_id, list_index_1, list_index_2);
//        };

        // assert state == `from` then change to `to`
        assert_and_change_task_state<TaskType>(task_id, from, to);

        // ----->> insert to disabled
//        if (disable) {
//            insert_disabled<TaskType>(task_id);
//        };
    }

    public(friend) fun task_state<TaskType: store>(task_id: &TaskId): u8 acquires TaskStore {
        // assert contains
        assert_task_contains<TaskType>(task_id);

        let publisher = TaskId7::publisher(task_id);
        let task_table = &borrow_global<TaskStore<TaskType>>(publisher).task_table;

        *&Table::borrow(task_table, *task_id).state
    }

    public(friend) fun task_data<TaskType: copy + store>(task_id: &TaskId): TaskType acquires TaskStore {
        // assert contains
        assert_task_contains<TaskType>(task_id);

        let publisher = TaskId7::publisher(task_id);
        let task_table = &borrow_global<TaskStore<TaskType>>(publisher).task_table;

        *&Table::borrow(task_table, *task_id).data
    }

    public(friend) fun assert_task_contains<TaskType: store>(task_id: &TaskId) acquires TaskStore {
        let error_code = Errors::invalid_argument(ETASK_ID_NOT_FOUND);
        let publisher = TaskId7::publisher(task_id);
        let task_table = &borrow_global<TaskStore<TaskType>>(publisher).task_table;
        assert!(
            Table::contains(task_table, *task_id),
            error_code
        );
    }

    // --------------------------------------------------------------------------------------------

//    fun assert_task_enabled<TaskType: store>(task_id: &TaskId, error_code: u64): (u64, u64)
//    acquires TaskEnabled {
//        let (publisher, performer) = TaskId7::addresses_of(task_id);
//
//        let task_id_list = &borrow_global<TaskEnabled<TaskType>>(publisher).task_id_list;
//        let (is_exist, list_index_1) = Vector::index_of(task_id_list, task_id);
//        assert!(is_exist, error_code);
//
//        let task_id_list = &borrow_global<TaskEnabled<TaskType>>(performer).task_id_list;
//        let (is_exist, list_index_2) = Vector::index_of(task_id_list, task_id);
//        assert!(is_exist, error_code);
//
//        (list_index_1, list_index_2)
//    }

    fun assert_and_change_task_state<TaskType: store>(task_id: &TaskId, from: u8, to: u8) acquires TaskStore {
        let publisher = TaskId7::publisher(task_id);
        let task_table = &mut borrow_global_mut<TaskStore<TaskType>>(publisher).task_table;
        let task_holder = Table::borrow_mut<TaskId, TaskHolder<TaskType>>(task_table, *task_id);
        // assert state == from
        assert!(task_holder.state == from, Errors::invalid_state(ETASK_STATE_NOT_MATCHED));
        task_holder.state = to;
    }

//    fun remove_enabled<TaskType: store>(task_id: &TaskId, task_index_1: u64, task_index_2: u64) acquires TaskEnabled {
//        let (publisher, performer) = TaskId7::addresses_of(task_id);
//
//        let task_id_list = &mut borrow_global_mut<TaskEnabled<TaskType>>(publisher).task_id_list;
//        Vector::remove(task_id_list, task_index_1);
//
//        let task_id_list = &mut borrow_global_mut<TaskEnabled<TaskType>>(performer).task_id_list;
//        Vector::remove(task_id_list, task_index_2);
//    }
//
//    fun insert_disabled<TaskType: store>(task_id: &TaskId) acquires TaskDisabled {
//        let (publisher, performer) = TaskId7::addresses_of(task_id);
//
//        let task_id_list = &mut borrow_global_mut<TaskDisabled<TaskType>>(publisher).task_id_list;
//        Vector::push_back(task_id_list, *task_id);
//
//        let task_id_list = &mut borrow_global_mut<TaskDisabled<TaskType>>(performer).task_id_list;
//        Vector::push_back(task_id_list, *task_id);
//    }

//    fun on_task_add<TaskType: store>(task_id: &TaskId) acquires TaskEnabled {
//        let (publisher, performer) = TaskId7::addresses_of(task_id);
//        // insert to list
//        let store = borrow_global_mut<TaskEnabled<TaskType>>(publisher);
//        Vector::push_back(&mut store.task_id_list, *task_id);
//        let store = borrow_global_mut<TaskEnabled<TaskType>>(performer);
//        Vector::push_back(&mut store.task_id_list, *task_id);
//    }
}
