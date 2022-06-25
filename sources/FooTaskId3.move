module ModAddr::FooTaskId3 {
	friend ModAddr::FooTask3;

	use Std::Errors;

	const ETASK_ID_ADDRESS_SAME: u64 = 0;

	struct TaskId has copy, drop, store {
  	index: u128,
  	publisher: address,
  	performer: address
  }

  struct TaskIdCounter has key {
    counter: u128,
  }

  public(friend) fun initialize(account: &signer){
		move_to(account, TaskIdCounter {
			counter: 0,
		});
  }

  public(friend) fun new(publisher: address, performer: address): TaskId acquires TaskIdCounter {
    // assert pub != pfm
    assert!(publisher != performer, Errors::invalid_argument(ETASK_ID_ADDRESS_SAME));
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

  public(friend) fun get(publisher: address, performer: address, index: u128): TaskId {
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
}