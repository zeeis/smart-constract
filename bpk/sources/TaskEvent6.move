module ModAddr::TaskEvent6 {
    friend ModAddr::Task6;

    use Std::Event;
    use ModAddr::TaskId6::{Self, TaskId};
    use AptosFramework::Timestamp;

    struct TaskEventStore has key {
        task_create_events: Event::EventHandle<TaskCreateEvent>,
        task_state_change_events: Event::EventHandle<TaskStateChangeEvent>,
    }

    struct TaskCreateEvent has store, drop {
        id: TaskId,
        timestamp: u64,
    }

    struct TaskStateChangeEvent has store, drop {
        id: TaskId,
        timestamp: u64,
        state_from: u8,
        state_to: u8,
    }

    public(friend) fun initialize(account: &signer) {
        move_to(account, TaskEventStore {
            task_create_events: Event::new_event_handle<TaskCreateEvent>(account),
            task_state_change_events: Event::new_event_handle<TaskStateChangeEvent>(account),
        });
    }

    public(friend) fun emit_task_create(task_id: &TaskId) acquires TaskEventStore {
        let (publisher, performer) = TaskId6::addresses_of(task_id);

        let store = borrow_global_mut<TaskEventStore>(publisher);
        Event::emit_event(&mut store.task_create_events, TaskCreateEvent {
            id: *task_id,
            timestamp: Timestamp::now_seconds(),
        });
        let store = borrow_global_mut<TaskEventStore>(performer);
        Event::emit_event(&mut store.task_create_events, TaskCreateEvent {
            id: *task_id,
            timestamp: Timestamp::now_seconds(),
        });
    }

    public(friend) fun emit_task_state_change(task_id: &TaskId, from: u8, to: u8) acquires TaskEventStore {
        let (publisher, performer) = TaskId6::addresses_of(task_id);

        let store = borrow_global_mut<TaskEventStore>(publisher);
        Event::emit_event(&mut store.task_state_change_events, TaskStateChangeEvent {
            id: *task_id,
            timestamp: Timestamp::now_seconds(),
            state_from: from,
            state_to: to,
        });
        let store = borrow_global_mut<TaskEventStore>(performer);
        Event::emit_event(&mut store.task_state_change_events, TaskStateChangeEvent {
            id: *task_id,
            timestamp: Timestamp::now_seconds(),
            state_from: from,
            state_to: to,
        });
    }
}
