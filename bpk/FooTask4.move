module ModAddr::FooTask4 {
	use Std::ASCII;
	use Std::Errors;
	use Std::Signer;

  use ModAddr::FooTaskId4::{Self, TaskId};
  use ModAddr::FooTaskStore4;
  use ModAddr::FooTaskEvent4;

  use 0x1::Coin;
  use 0x1::TestCoin::{TestCoin};

	const ETASK: u64 = 0;

	const TS_PUBLISHED: u8 = 0;
  const TS_CANCELED: u8 = 1;
  const TS_ACCEPTED: u8 = 2;
  const TS_ABANDONED: u8 = 3;
  const TS_UNCONFIRM: u8 = 4;
  const TS_SUCCEEDED: u8 = 5;
  const TS_FAILED: u8 = 6;

	fun assert_initialized(addr: address) {
    assert!(FooTaskStore4::is_initialized(addr), Errors::not_published(ETASK));
  }

	public(script) fun initialize(account: &signer) {
		// assert not initialize
		let addr = Signer::address_of(account);
    assert!(!FooTaskStore4::is_initialized(addr), Errors::already_published(ETASK));

		FooTaskId4::initialize(account);
		FooTaskEvent4::initialize(account);
		FooTaskStore4::initialize(account);
	}

	public(script) fun publish_task(publisher: &signer, performer_addr: address, meta_bytes: vector<u8>) {
		let publisher_addr = Signer::address_of(publisher);
		assert_initialized(publisher_addr);
		assert_initialized(performer_addr);

		let meta_data = ASCII::string(meta_bytes);
    let task_id = FooTaskId4::new(publisher_addr, performer_addr);
		FooTaskStore4::task_add(task_id, meta_data);
		FooTaskEvent4::emit_task_create(&task_id);
	}

	public(script) fun cancel_task(publisher: &signer, performer_addr: address, index: u128) {
		let publisher_addr = Signer::address_of(publisher);
    assert_initialized(publisher_addr);
    assert_initialized(performer_addr);

    let task_id = FooTaskId4::get(publisher_addr, performer_addr, index);
    FooTaskStore4::task_change_state(&task_id, TS_PUBLISHED, TS_CANCELED, true);
    on_repay(publisher, &task_id);
    FooTaskEvent4::emit_task_state_change(&task_id, TS_PUBLISHED, TS_CANCELED);
	}

//	fun transfer(from: &signer, addr: address, amount: u64) {
//
//	}

	fun on_repay(publisher: &signer, task_id: &TaskId){
		// assert publisher
		let to = FooTaskId4::performer(task_id);
    let coin = Coin::withdraw<TestCoin>(publisher, 300);
    Coin::deposit(to, coin);
	}

	// -------------------------------------------------------------------------
//	#[test(account = @0x18a2a9c61ead36a7727fa6be287e70c44b84f403f70a4086080dcf2bc5ff4440)]
//	public(script) fun test_call_transfer(account: signer) {
//		let to = @0xbe3709420f9b9b0fc40980e3c33e8813b5f6e209b69d2c94e03d0bd55beca47f;
//    let coin = Coin::withdraw<TestCoin>(&account, 300);
//    Coin::deposit(to, coin);
//	}

	#[test(account = @0x1, account2 = @0x2)]
	public(script) fun can_set_table(account: signer, account2: signer) {

		initialize(&account);
		initialize(&account2);

		let addr1 = Signer::address_of(&account);
		let addr2 = Signer::address_of(&account2);
		let meta = b"Foobar";
		let task_id = FooTaskId4::get(addr1, addr2, 0);

		publish_task(&account, addr2, meta);
	  assert!(FooTaskStore4::task_state(&task_id) == TS_PUBLISHED, 0);

	  cancel_task(&account, addr2, 0);
	  assert!(FooTaskStore4::task_state(&task_id) == TS_CANCELED, 1);
	}
}
