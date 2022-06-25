module ModAddr::FooTask3 {
	use Std::ASCII;
	use Std::Errors;
	use Std::Signer;

  use ModAddr::FooTaskId3;
  use ModAddr::FooTaskStore3;
  use ModAddr::FooTaskEvent3;

	const ETASK: u64 = 0;

	const TS_PUBLISHED: u8 = 0;
  const TS_CANCELED: u8 = 1;
  const TS_ACCEPTED: u8 = 2;
  const TS_ABANDONED: u8 = 3;
  const TS_UNCONFIRM: u8 = 4;
  const TS_SUCCEEDED: u8 = 5;
  const TS_FAILED: u8 = 6;

	public(script) fun initialize(account: &signer) {
		// assert not initialize
		let addr = Signer::address_of(account);
    assert!(!FooTaskStore3::is_initialized(addr), Errors::already_published(ETASK));

		FooTaskId3::initialize(account);
		FooTaskEvent3::initialize(account);
		FooTaskStore3::initialize(account);
	}

	fun assert_initialized(addr: address) {
    assert!(FooTaskStore3::is_initialized(addr), Errors::not_published(ETASK));
  }

	public(script) fun publish_task(publisher: &signer, performer_addr: address, meta_bytes: vector<u8>) {
		let publisher_addr = Signer::address_of(publisher);
		assert_initialized(publisher_addr);
		assert_initialized(performer_addr);

		let meta_data = ASCII::string(meta_bytes);
    let task_id = FooTaskId3::new(publisher_addr, performer_addr);
		FooTaskStore3::task_add(task_id, meta_data);
		FooTaskEvent3::emit_task_create(&task_id);
	}

	public(script) fun cancel_task(publisher: &signer, performer_addr: address, index: u128) {
		let publisher_addr = Signer::address_of(publisher);
    assert_initialized(publisher_addr);
    assert_initialized(performer_addr);

    let task_id = FooTaskId3::get(publisher_addr, performer_addr, index);
    FooTaskStore3::task_change_state(&task_id, TS_PUBLISHED, TS_CANCELED, true);
    FooTaskEvent3::emit_task_state_change(&task_id, TS_PUBLISHED, TS_CANCELED);
	}

	// -------------------------------------------------------------------------
	#[test(account = @0x1, account2 = @0x2)]
	public(script) fun can_set_table(account: signer, account2: signer) {

		initialize(&account);
		initialize(&account2);

		let addr1 = Signer::address_of(&account);
		let addr2 = Signer::address_of(&account2);
		let meta = b"Foobar";
		let task_id = FooTaskId3::get(addr1, addr2, 0);

		publish_task(&account, addr2, meta);
	  assert!(FooTaskStore3::task_state(&task_id) == TS_PUBLISHED, 0);

	  cancel_task(&account, addr2, 0);
	  assert!(FooTaskStore3::task_state(&task_id) == TS_CANCELED, 1);
	}
}
