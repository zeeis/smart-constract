/// This module defines a struct storing the metadata of the block and new block events.
module AptosFramework::Block {
    use Std::Errors;
    use Std::Event;

    use AptosFramework::GovernanceProposal::GovernanceProposal;
    use AptosFramework::Timestamp;
    use AptosFramework::SystemAddresses;
    use AptosFramework::Reconfiguration;
    use AptosFramework::Stake;

    struct BlockMetadata has key {
        /// Height of the current block
        height: u64,
        /// Time period between epochs.
        epoch_internal: u64,
        /// Handle where events with the time of new blocks are emitted
        new_block_events: Event::EventHandle<Self::NewBlockEvent>,
    }

    struct NewBlockEvent has drop, store {
        epoch: u64,
        round: u64,
        previous_block_votes: vector<bool>,
        proposer: address,
        failed_proposer_indices: vector<u64>,
        /// On-chain time during  he block at the given height
        time_microseconds: u64,
    }

    /// The `BlockMetadata` resource is in an invalid state
    const EBLOCK_METADATA: u64 = 0;
    /// An invalid signer was provided. Expected the signer to be the VM or a Validator.
    const EVM_OR_VALIDATOR: u64 = 1;

    /// This can only be called during Genesis.
    public fun initialize_block_metadata(account: &signer, epoch_internal: u64) {
        Timestamp::assert_genesis();
        SystemAddresses::assert_core_resource(account);

        assert!(!is_initialized(), Errors::already_published(EBLOCK_METADATA));
        move_to<BlockMetadata>(
            account,
            BlockMetadata {
                height: 0,
                epoch_internal,
                new_block_events: Event::new_event_handle<Self::NewBlockEvent>(account),
            }
        );
    }

    /// Update the epoch interval.
    /// Can only be called as part of the Aptos governance proposal process established by the AptosGovernance module.
    public fun update_epoch_interval(
        _gov_proposal: GovernanceProposal,
        new_epoch_interval: u64,
    ) acquires BlockMetadata {
        let block_metadata = borrow_global_mut<BlockMetadata>(@CoreResources);
        block_metadata.epoch_internal = new_epoch_interval;
    }

    /// Helper function to determine whether this module has been initialized.
    fun is_initialized(): bool {
        exists<BlockMetadata>(@CoreResources)
    }

    /// Set the metadata for the current block.
    /// The runtime always runs this before executing the transactions in a block.
    fun block_prologue(
        vm: signer,
        epoch: u64,
        round: u64,
        previous_block_votes: vector<bool>,
        missed_votes: vector<u64>,
        proposer: address,
        failed_proposer_indices: vector<u64>,
        timestamp: u64
    ) acquires BlockMetadata {
        Timestamp::assert_operating();
        // Operational constraint: can only be invoked by the VM.
        SystemAddresses::assert_vm(&vm);

        // Authorization
        assert!(
            proposer == @VMReserved || Stake::is_current_validator(proposer),
            Errors::requires_address(EVM_OR_VALIDATOR)
        );

        let block_metadata_ref = borrow_global_mut<BlockMetadata>(@CoreResources);
        Timestamp::update_global_time(&vm, proposer, timestamp);
        block_metadata_ref.height = block_metadata_ref.height + 1;
        Event::emit_event<NewBlockEvent>(
            &mut block_metadata_ref.new_block_events,
            NewBlockEvent {
                epoch,
                round,
                previous_block_votes,
                proposer,
                failed_proposer_indices,
                time_microseconds: timestamp,
            }
        );

        // Performance scores have to be updated before the epoch transition as the transaction that triggers the
        // transition is the last block in the previous epoch.
        Stake::update_performance_statistics(missed_votes);

        if (timestamp - Reconfiguration::last_reconfiguration_time() > block_metadata_ref.epoch_internal) {
            Reconfiguration::reconfigure();
        };
    }

    /// Get the current block height
    public fun get_current_block_height(): u64 acquires BlockMetadata {
        assert!(is_initialized(), Errors::not_published(EBLOCK_METADATA));
        borrow_global<BlockMetadata>(@CoreResources).height
    }
}
