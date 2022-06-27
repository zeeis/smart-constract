module ModAddr::DataProvidingTask1 {
	use ModAddr::FooTask4;
//  use 0x1::Coin;
//  use 0x1::TestCoin::{TestCoin};

	const TS_PUBLISHED: u8 = 0;
  const TS_CANCELED: u8 = 1;
  const TS_ACCEPTED: u8 = 2;
  const TS_ABANDONED: u8 = 3;
  const TS_UNCONFIRM: u8 = 4;
  const TS_SUCCEEDED: u8 = 5;
  const TS_FAILED: u8 = 6;

	struct DataProvidingTask has copy, store, drop {
		amount: u64
	}

	public(script) fun initialize(account: &signer) {
		FooTask4::initialize<DataProvidingTask>(account);
	}

	public(script) fun task_publish(
		account: &signer,
		provider_addr: address,
		amount: u64,
		meta_bytes: vector<u8>
	) {
		let data = DataProvidingTask {
			amount,
		};
		FooTask4::task_publish<DataProvidingTask>(account, provider_addr, data, meta_bytes);
		// withdraw
	}

	public(script) fun task_cancel(
		account: &signer,
		provider_addr: address,
		index: u128
	) {
		let task_id = FooTask4::get_task_id_from_publisher(account, provider_addr, index);
	  FooTask4::task_change_state<DataProvidingTask>(&task_id, TS_PUBLISHED, TS_CANCELED, true);
	  // deposit
	}

//	fun on_repay(publisher: &signer, task_id: &TaskId){
//		// assert publisher
//		let to = FooTaskId4::performer(task_id);
//    let coin = Coin::withdraw<TestCoin>(publisher, 300);
//    Coin::deposit(to, coin);
//	}

	#[test_only]
	use Std::Signer;

	#[test(account = @0x1, account2 = @0x2)]
	public(script) fun test_data_providing_task(account: signer, account2: signer) {

		initialize(&account);
		initialize(&account2);

//		let addr1 = Signer::address_of(&account);
		let addr2 = Signer::address_of(&account2);
		let meta = b"Foobar";

		task_publish(&account, addr2, 300, meta);
		let task_id = FooTask4::get_task_id_from_publisher(&account, addr2, 0);
	  assert!(FooTask4::task_state<DataProvidingTask>(&task_id) == TS_PUBLISHED, 0);

	  task_cancel(&account, addr2, 0);
	  assert!(FooTask4::task_state<DataProvidingTask>(&task_id) == TS_CANCELED, 1);

	  let data = FooTask4::task_data<DataProvidingTask>(&task_id);
	  assert!(data.amount == 300, 2);
	}
}