module ModAddr::Transfer14 {
    use AptosFramework::Coin;
    use Std::Event;
    use AptosFramework::Timestamp;
    use Std::Signer;

    struct TransferEvent has store, drop {
        coin_type: vector<u8>,
        from: address,
        to: address,
        amount: u64,
        timestamp: u64,
    }

    struct CoinEventStore has key {
        transfer_events: Event::EventHandle<TransferEvent>,
    }

    public(script) fun initialize(account: &signer) {
        move_to(account, CoinEventStore {
            transfer_events: Event::new_event_handle<TransferEvent>(account),
        });
    }

    public(script) fun transfer<CoinType> (
        from: &signer,
        to: address,
        amount: u64,
        coin_type: vector<u8>,
    ) acquires CoinEventStore {
        let coin = Coin::withdraw<CoinType>(from, amount);
        Coin::deposit<CoinType>(to, coin);

        let timestamp = Timestamp::now_seconds();
        let from_addr = Signer::address_of(from);
        let store = borrow_global_mut<CoinEventStore>(from_addr);
        Event::emit_event(&mut store.transfer_events, TransferEvent {
            coin_type,
            from: from_addr,
            to,
            amount,
            timestamp,
        });

        if (from_addr != to) {
            let store = borrow_global_mut<CoinEventStore>(to);
            Event::emit_event(&mut store.transfer_events, TransferEvent {
                coin_type,
                from: from_addr,
                to,
                amount,
                timestamp,
            });
        }
    }
}
