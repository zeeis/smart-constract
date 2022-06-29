module ModAddr::Task4 {
	use Std::ASCII;
	use Std::Errors;
	use Std::Signer;

  use ModAddr::TaskId4::{Self, TaskId};
  use ModAddr::TaskStore4;
  use ModAddr::TaskEvent4;

	const ETASK: u64 = 0;

	const TS_PUBLISHED: u8 = 0;
  const TS_CANCELED: u8 = 1;
  const TS_ACCEPTED: u8 = 2;
  const TS_ABANDONED: u8 = 3;
  const TS_UNCONFIRM: u8 = 4;
  const TS_SUCCEEDED: u8 = 5;
  const TS_FAILED: u8 = 6;

	public fun assert_initialized<TaskType: store>(addr: address) {
    assert!(TaskStore4::is_initialized<TaskType>(addr), Errors::not_published(ETASK));
  }

	public fun initialize<TaskType: store>(account: &signer) {
		// assert not initialize
		let addr = Signer::address_of(account);
    assert!(!TaskStore4::is_initialized<TaskType>(addr), Errors::already_published(ETASK));

		TaskId4::initialize(account);
		TaskEvent4::initialize(account);

		TaskStore4::initialize<TaskType>(account);
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
    let task_id = TaskId4::new(publisher, publisher_addr, performer_addr);
		TaskStore4::task_add<TaskType>(task_id, data, meta_data);
		TaskEvent4::emit_task_create(&task_id);
		task_id
	}

	public fun task_change_state<TaskType: store>(
		task_id: &TaskId,
		from: u8,
		to: u8,
		disabled: bool
	) {
		let (publisher, performer) = TaskId4::addresses_of(task_id);
    assert_initialized<TaskType>(publisher);
    assert_initialized<TaskType>(performer);

    TaskStore4::task_change_state<TaskType>(task_id, from, to, disabled);
    TaskEvent4::emit_task_state_change(task_id, from, to);
	}

	public fun get_task_id_from_publisher(account: &signer, performer: address, index: u128): TaskId {
		let publisher = Signer::address_of(account);
    TaskId4::get(account, publisher, performer, index)
	}

	public fun get_task_id_from_performer(account: &signer, publisher: address, index: u128): TaskId {
		let performer = Signer::address_of(account);
    TaskId4::get(account, publisher, performer, index)
	}

	public fun task_state<TaskType: store>(task_id: &TaskId): u8 {
		TaskStore4::task_state<TaskType>(task_id)
	}

	public fun task_data<TaskType: copy + store>(task_id: &TaskId): TaskType {
		TaskStore4::task_data<TaskType>(task_id)
	}

	public fun assert_task_exists<TaskType: store>(task_id: &TaskId) {
		TaskStore4::assert_task_contains<TaskType>(task_id);
	}

}
