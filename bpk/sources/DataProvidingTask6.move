module ModAddr::DataProvidingTask6 {
    use Std::Signer;

    use AptosFramework::Table::{Self, Table};
    use AptosFramework::Coin::{Self, Coin};

    use ModAddr::Task6;
    use ModAddr::TaskId6::{Self, TaskId};

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

    struct DataProvidingTask has copy, store {
        amount: u64,
    }

    struct CoinStore<phantom CopyType> has key {
        coin_table: Table<TaskId, Coin<CopyType>>,
    }

    public(script) fun initialize<CoinType>(account: &signer) {
        move_to(account, CoinStore<CoinType> {
            coin_table: Table::new<TaskId, Coin<CoinType>>(),
        });
        Task6::initialize<DataProvidingTask>(account);
    }

    public(script) fun task_publish<CoinType>(
        receiver: &signer,
        provider_addr: address,
        amount: u64,
        meta_bytes: vector<u8>
    )  acquires CoinStore {
        let data = DataProvidingTask {
            amount,
        };
        let task_id = Task6::task_publish<DataProvidingTask>(receiver, provider_addr, data, meta_bytes);
        withdraw<CoinType>(receiver, &task_id, amount);
    }

    public(script) fun task_cancel<CoinType>(
        receiver: &signer,
        provider_addr: address,
        index: u128
    ) acquires CoinStore {
        let task_id = Task6::get_task_id_from_publisher(receiver, provider_addr, index);
        Task6::task_change_state<DataProvidingTask>(&task_id, TS_PUBLISHED, TS_CANCELED, true);
        deposit_back<CoinType>(&task_id);
    }

    // unsafe
    public(script) fun task_accept_and_submit<CoinType>(
        provider: &signer,
        receiver_addr: address,
        index: u128,
        abandoned: bool
    ) acquires CoinStore {
        let task_id = Task6::get_task_id_from_performer(provider, receiver_addr, index);
        let task_state = if (abandoned) { TS_ABANDONED } else { TS_UNCONFIRM };
        Task6::task_change_state<DataProvidingTask>(&task_id, TS_PUBLISHED, task_state, abandoned);
        // todo: deposit_back if abandoned
        if (abandoned) {
            deposit_back<CoinType>(&task_id);
        }
    }

    // disabled
    public(script) fun task_accept(
        provider: &signer,
        receiver_addr: address,
        index: u128
    ) {
        let task_id = Task6::get_task_id_from_performer(provider, receiver_addr, index);
        Task6::task_change_state<DataProvidingTask>(&task_id, TS_PUBLISHED, TS_ACCEPTED, false);
    }

    // disabled
    public(script) fun task_submit<CoinType>(
        provider: &signer,
        receiver_addr: address,
        index: u128,
        abandoned: bool
    ) acquires CoinStore {
        let task_id = Task6::get_task_id_from_performer(provider, receiver_addr, index);
        let task_state = if (abandoned) { TS_ABANDONED } else { TS_UNCONFIRM };
        Task6::task_change_state<DataProvidingTask>(&task_id, TS_ACCEPTED, task_state, abandoned);
        if (abandoned) {
            deposit_back<CoinType>(&task_id);
        }
    }

    public(script) fun task_confirm<CoinType>(
        receiver: &signer,
        provider_addr: address,
        index: u128,
        failed: bool
    ) acquires CoinStore {
        let task_id = Task6::get_task_id_from_publisher(receiver, provider_addr, index);
        let task_state = if (failed) { TS_FAILED } else { TS_SUCCEEDED };
        Task6::task_change_state<DataProvidingTask>(&task_id, TS_UNCONFIRM, task_state, true);
        if (failed) {
            deposit_back<CoinType>(&task_id);
        } else {
            deposit_to<CoinType>(&task_id);
        }
    }

    // ---------------------------------------------------------------------------------------------

    fun withdraw<CoinType>(publisher: &signer, task_id: &TaskId, amount: u64) acquires CoinStore {
        let publisher_addr = Signer::address_of(publisher);
        let table = &mut borrow_global_mut<CoinStore<CoinType>>(publisher_addr).coin_table;
        let coin = Coin::withdraw<CoinType>(publisher, amount);
        Table::add(table, *task_id, coin);
    }

    fun deposit_back<CoinType>(task_id: &TaskId) acquires CoinStore {
        let addr = TaskId6::publisher(task_id);
        let table = &mut borrow_global_mut<CoinStore<CoinType>>(addr).coin_table;
        let coin = Table::remove<TaskId, Coin<CoinType>>(table, *task_id);
        Coin::deposit<CoinType>(addr, coin);
    }

    fun deposit_to<CoinType>(task_id: &TaskId) acquires CoinStore {
        let (publisher_addr, addr) = TaskId6::addresses_of(task_id);
        let table = &mut borrow_global_mut<CoinStore<CoinType>>(publisher_addr).coin_table;
        let coin = Table::remove<TaskId, Coin<CoinType>>(table, *task_id);
        Coin::deposit<CoinType>(addr, coin);
    }

    //	#[test(account = @0x1, account2 = @0x2)]
    //	public(script) fun test_data_providing_task(account: signer, account2: signer) acquires CoinStore {
    //
    //		initialize<TestCoin>(&account);
    //		initialize<TestCoin>(&account2);
    //
    //		let addr1 = Signer::address_of(&account);
    //		let addr2 = Signer::address_of(&account2);
    //		let meta = b"Foobar";
    //
    //		task_publish(&account, addr2, 300, meta);
    //		let task_id = Task6::get_task_id_from_publisher(&account, addr2, 0);
    //	  assert!(Task6::task_state<DataProvidingTask>(&task_id) == TS_PUBLISHED, 0);
    //
    //	  task_cancel(&account, addr2, 0);
    //	  assert!(Task6::task_state<DataProvidingTask>(&task_id) == TS_CANCELED, 1);
    //
    //	  let DataProvidingTask { amount } = Task6::task_data<DataProvidingTask>(&task_id);
    //	  assert!(amount == 300, 2);
    //	}
}
