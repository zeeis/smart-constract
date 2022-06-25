module ModAddr::FooTaskEvent3 {
	friend ModAddr::FooTask3;

	use Std::Event;
	use ModAddr::FooTaskId3::{Self, TaskId};

	struct TaskCreateEventStore has key {
		task_create_events: Event::EventHandle<TaskCreateEvent>,
	}

	struct TaskStateChangeEventStore has key {
    task_state_change_events: Event::EventHandle<TaskStateChangeEvent>,
	}

	struct TaskCreateEvent has store, drop {
    id: TaskId,
  }

	struct TaskStateChangeEvent has store, drop {
	  id: TaskId,
	  state_from: u8,
	  state_to: u8,
	}

	public(friend) fun initialize(account: &signer) {
		move_to(account, TaskCreateEventStore {
			task_create_events: Event::new_event_handle<TaskCreateEvent>(account),
		});
		move_to(account, TaskStateChangeEventStore {
			task_state_change_events: Event::new_event_handle<TaskStateChangeEvent>(account),
		});
	}

	public(friend) fun emit_task_create(task_id: &TaskId) acquires TaskCreateEventStore {
		let (publisher, performer) = FooTaskId3::addresses_of(task_id);

		let store = borrow_global_mut<TaskCreateEventStore>(publisher);
		Event::emit_event(&mut store.task_create_events, TaskCreateEvent {
      id: *task_id,
    });
		let store = borrow_global_mut<TaskCreateEventStore>(performer);
		Event::emit_event(&mut store.task_create_events, TaskCreateEvent {
      id: *task_id,
    });
	}

	public(friend) fun emit_task_state_change(task_id: &TaskId, from: u8, to: u8) acquires TaskStateChangeEventStore {
		let (publisher, performer) = FooTaskId3::addresses_of(task_id);

		let store = borrow_global_mut<TaskStateChangeEventStore>(publisher);
		Event::emit_event(&mut store.task_state_change_events, TaskStateChangeEvent {
		  id: *task_id,
		  state_from: from,
		  state_to: to,
		});
		let store = borrow_global_mut<TaskStateChangeEventStore>(performer);
		Event::emit_event(&mut store.task_state_change_events, TaskStateChangeEvent {
		  id: *task_id,
		  state_from: from,
		  state_to: to,
		});
  }

  // -------------------------------------------------------------------------------------------------------------------

	#[test(account = @0x1)]
  public(script) fun test_event_init(account: signer) {
    initialize(&account);
  }

}