module ModAddr::DataProvidingTask1 {
	use Std::Signer;

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

	struct DataProvidingTask has store {
		amount: u64
	}

	public(script) fun initialize(account: &signer) {
		FooTask4::initialize<DataProvidingTask>(account);
	}

	public(script) fun task_publish(
		account: &signer,
		provider: address,
		_amount: u64,
		meta_bytes: vector<u8>
	) {
		FooTask4::task_publish<DataProvidingTask>(account, provider, meta_bytes);
	}

	public(script) fun task_cancel(
		account: &signer,
		provider: address,
		index: u128
	) {
	  FooTask4::task_change_state<DataProvidingTask>(
	    account,
	    provider,
	    index,
	    TS_PUBLISHED,
	    TS_CANCELED,
	    true
    );
	}

	#[test(account = @0x1, account2 = @0x2)]
	public(script) fun test_data_providing_task(account: signer, account2: signer) {

		initialize(&account);
		initialize(&account2);

		let addr1 = Signer::address_of(&account);
		let addr2 = Signer::address_of(&account2);
		let meta = b"Foobar";

		task_publish(&account, addr2, 300, meta);
	  assert!(FooTask4::task_state<DataProvidingTask>(addr1, addr2, 0) == TS_PUBLISHED, 0);

	  task_cancel(&account, addr2, 0);
	  assert!(FooTask4::task_state<DataProvidingTask>(addr1, addr2, 0) == TS_CANCELED, 1);
	}
}