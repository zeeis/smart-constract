module ModAddr::Transfer7 {
    use AptosFramework::Coin;
    use Std::Signer;

    #[test_only]
    use AptosFramework::TestCoin::TestCoin;

    public(script) fun transfer<CoinType>(
        from: &signer,
        to: address,
        amount: u64,
    ) {
        Coin::transfer<CoinType>(from, to, amount)
    }

    #[test(account = @0x1, account2 = @0x2)]
    public(script) fun test_transfer(account: signer, account2: signer) {
//        let addr1 = Signer::address_of(&account);
        let addr2 = Signer::address_of(&account2);
        transfer<TestCoin>(&account, addr2, 100)
    }
}
