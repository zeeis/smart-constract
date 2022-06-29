module ModAddr::DataProvidingTask1 {
	use ModAddr::FooTask4;

	use AptosFramework::Coin::{Self, Coin};
	use AptosFramework::TestCoin::{TestCoin};

	/*

	published   <- publish
	unconfirm   <- submit
	succeeded   <- confirm

	*/

	/*

	published     <- publish
		canceled      <- cancel
		accepted      <- accept
			abandoned     <- submit (true)
			unconfirm     <- submit (false)
				failed        <- confirm (true)
				succeeded     <- confirm (false)

	*/

	const TS_PUBLISHED: u8 = 0;
  const TS_CANCELED: u8 = 1;
  const TS_ACCEPTED: u8 = 2;
  const TS_ABANDONED: u8 = 3;
  const TS_UNCONFIRM: u8 = 4;
  const TS_SUCCEEDED: u8 = 5;
  const TS_FAILED: u8 = 6;

	struct DataProvidingTask has store {
		amount: u64,
//		coin: Coin<TestCoin>,
	}

	public(script) fun initialize(account: &signer) {
		FooTask4::initialize<DataProvidingTask>(account);
	}

	public(script) fun task_publish(
		receiver: &signer,
		provider_addr: address,
		amount: u64,
		meta_bytes: vector<u8>
	) {
		let data = DataProvidingTask {
			amount,
//			coin: withdraw(receiver, amount),
		};
		FooTask4::task_publish<DataProvidingTask>(receiver, provider_addr, data, meta_bytes);
	}

	public(script) fun task_cancel(
		receiver: &signer,
		provider_addr: address,
		index: u128
	) {
		let task_id = FooTask4::get_task_id_from_publisher(receiver, provider_addr, index);
	  FooTask4::task_change_state<DataProvidingTask>(&task_id, TS_PUBLISHED, TS_CANCELED, true);
	}

	// unsafe
	public(script) fun task_accept_and_submit(
  	provider: &signer,
  	receiver_addr: address,
  	index: u128,
  	abandoned: bool
  ) {
    let task_id = FooTask4::get_task_id_from_performer(provider, receiver_addr, index);
    let task_state = if (abandoned) { TS_ABANDONED } else { TS_UNCONFIRM };
    FooTask4::task_change_state<DataProvidingTask>(&task_id, TS_PUBLISHED, task_state, abandoned);
  }
	// disable
	public(script) fun task_accept(
		provider: &signer,
		receiver_addr: address,
		index: u128
	) {
		let task_id = FooTask4::get_task_id_from_performer(provider, receiver_addr, index);
	  FooTask4::task_change_state<DataProvidingTask>(&task_id, TS_PUBLISHED, TS_ACCEPTED, false);
	}
	// disable
	public(script) fun task_submit(
		provider: &signer,
		receiver_addr: address,
		index: u128,
		abandoned: bool
	) {
		let task_id = FooTask4::get_task_id_from_performer(provider, receiver_addr, index);
		let task_state = if (abandoned) { TS_ABANDONED } else { TS_UNCONFIRM };
	  FooTask4::task_change_state<DataProvidingTask>(&task_id, TS_ACCEPTED, task_state, abandoned);
	}

	public(script) fun task_confirm(
		receiver: &signer,
		provider_addr: address,
		index: u128,
		failed: bool
	) {
		let task_id = FooTask4::get_task_id_from_publisher(receiver, provider_addr, index);
		let task_state = if (failed) { TS_FAILED } else { TS_SUCCEEDED };
	  FooTask4::task_change_state<DataProvidingTask>(&task_id, TS_UNCONFIRM, task_state, true);
	}

	// ---------------------------------------------------------------------------------------------

	fun withdraw(publisher: &signer, amount: u64): Coin<TestCoin>  {
		Coin::withdraw<TestCoin>(publisher, amount)
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

//	  let data = FooTask4::task_data<DataProvidingTask>(&task_id);
//	  assert!(data.amount == 300, 2);
	}

}