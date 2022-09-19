/**
 * This is the general Voting module that can be used as part of a DAO Governance. Voting is designed to be used by
 * standalone governance modules, who has full control over the voting flow and is responsible for voting power
 * calculation and including proper capabilities when creating the proposal so resolution can go through.
 * On-chain governance of the Aptos network also uses Voting.
 *
 * The voting flow:
 * 1. The Voting module can be deployed at a known address (e.g. 0x1 for Aptos on-chain governance)
 * 2. The governance module, e.g. AptosGovernance, can be deployed later and define a GovernanceProposal resource type
 * that can also contain other information such as Capability resource for authorization.
 * 3. The governance module's owner can then register the ProposalType with Voting. This also hosts the proposal list
 * (forum) on the calling account.
 * 4. A proposer, through the governance module, can call Voting::create_proposal to create a proposal. create_proposal
 * cannot be called directly not through the governance module. A script hash of the resolution script that can later
 * be called to execute the proposal is required.
 * 5. A voter, through the governance module, can call Voting::vote on a proposal. vote requires passing a &ProposalType
 * and thus only the governance module that registers ProposalType can call vote.
 * 6. Once the proposal's expiration time has passed and more than the defined threshold has voted yes on the proposal,
 * anyone can call resolve which returns the content of the proposal (of type ProposalType) that can be used to execute.
 * 7. Only the resolution script with the same script hash specified in the proposal can call Voting::resolve as part of
 * the resolution process.
 */
module AptosFramework::Voting {
    use Std::Errors;
    use Std::Event::{Self, EventHandle};
    use Std::Option::{Self, Option};
    use Std::Signer;

    use AptosFramework::Table::{Self, Table};
    use AptosFramework::Timestamp;
    use AptosFramework::TransactionContext;
    use AptosFramework::TypeInfo::{Self, TypeInfo};

    /// Error codes.
    const EPROPOSAL_EXECUTION_HASH_NOT_MATCHING: u64 = 1;
    const EPROPOSAL_CANNOT_BE_RESOLVED: u64 = 2;
    const EPROPOSAL_ALREADY_RESOLVED: u64 = 3;

    /// ProposalStateEnum representing proposal state.
    const PROPOSAL_STATE_PENDING: u64 = 0;
    const PROPOSAL_STATE_SUCCEEDED: u64 = 1;
    /// Proposal has failed because either the min vote threshold is not met or majority voted no.
    const PROPOSAL_STATE_FAILED: u64 = 3;

    struct Proposal<ProposalType: store> has store {
        /// Required. Should contain enough information to execute later, for example the required capability.
        /// This is stored as an option so we can return it to governance when the proposal is resolved.
        execution_content: Option<ProposalType>,

        /// Required. The hash for the execution script module. Only the same exact script module can resolve this
        /// proposal.
        execution_hash: vector<u8>,

        /// A proposal is only resolved if expiration has passed and the number of votes is above threshold.
        min_vote_threshold: u128,
        expiration_secs: u64,

        /// Optional. Early resolution threshold. If specified, the proposal can be resolved early if the total
        /// number of yes or no votes passes this threshold.
        /// For example, this can be set to 50% of the total supply of the voting token, so if > 50% vote yes or no,
        /// the proposal can be resolved before expiration.
        early_resolution_vote_threshold: Option<u128>,

        /// Number of votes for each outcome.
        /// u128 since the voting power is already u64 and can add up to more than u64 can hold.
        yes_votes: u128,
        no_votes: u128,

        /// Whether the proposal has been resolved.
        is_resolved: bool,
    }

    struct VotingForum<ProposalType: store> has key {
        /// Use Table for execution optimization instead of Vector for gas cost since Vector is read entirely into memory
        /// during execution while only relevant Table entries are.
        proposals: Table<u64, Proposal<ProposalType>>,
        events: VotingEvents,
        /// Unique identifier for a proposal. This allows for 2 * 10**19 proposals.
        next_proposal_id: u64,
    }

    struct VotingEvents has store {
        create_proposal_events: EventHandle<CreateProposalEvent>,
        register_forum_events: EventHandle<RegisterForumEvent>,
        resolve_proposal_events: EventHandle<ResolveProposal>,
        vote_events: EventHandle<VoteEvent>,
    }

    struct CreateProposalEvent has drop, store {
        proposal_id: u64,
        early_resolution_vote_threshold: Option<u128>,
        execution_hash: vector<u8>,
        expiration_secs: u64,
        min_vote_threshold: u128,
    }

    struct RegisterForumEvent has drop, store {
        hosting_account: address,
        proposal_type_info: TypeInfo,
    }

    struct VoteEvent has drop, store {
        proposal_id: u64,
        num_votes: u64,
    }

    struct ResolveProposal has drop, store {
        proposal_id: u64,
        yes_votes: u128,
        no_votes: u128,
        resolved_early: bool
    }

    public fun register<ProposalType: store>(account: &signer) {
        let voting_forum = VotingForum<ProposalType> {
            next_proposal_id: 0,
            proposals: Table::new<u64, Proposal<ProposalType>>(),
            events: VotingEvents {
                create_proposal_events: Event::new_event_handle<CreateProposalEvent>(account),
                register_forum_events: Event::new_event_handle<RegisterForumEvent>(account),
                resolve_proposal_events: Event::new_event_handle<ResolveProposal>(account),
                vote_events: Event::new_event_handle<VoteEvent>(account),
            }
        };

        Event::emit_event<RegisterForumEvent>(
            &mut voting_forum.events.register_forum_events,
            RegisterForumEvent {
                hosting_account: Signer::address_of(account),
                proposal_type_info: TypeInfo::type_of<ProposalType>(),
            },
        );

        move_to(account, voting_forum);
    }

    /// Create a proposal with the given parameters
    ///
    /// @param voting_forum_address The forum's address where the proposal will be stored.
    /// @param execution_content The execution content that will be given back at resolution time. This can contain
    /// data such as a capability resource used to scope the execution.
    /// @param execution_hash The hash for the execution script module. Only the same exact script module can resolve
    /// this proposal.
    /// @param min_vote_threshold The minimum number of votes needed to consider this proposal successful.
    /// @param expiration_secs The time in seconds at which the proposal expires and can potentially be resolved.
    /// @return The proposal id.
    public fun create_proposal<ProposalType: store>(
        voting_forum_address: address,
        execution_content: ProposalType,
        execution_hash: vector<u8>,
        min_vote_threshold: u128,
        expiration_secs: u64,
        early_resolution_vote_threshold: Option<u128>,
    ): u64 acquires VotingForum {
        let voting_forum = borrow_global_mut<VotingForum<ProposalType>>(voting_forum_address);
        let proposal_id = voting_forum.next_proposal_id;
        voting_forum.next_proposal_id = voting_forum.next_proposal_id + 1;

        Table::add(&mut voting_forum.proposals, proposal_id, Proposal {
            execution_content: Option::some<ProposalType>(execution_content),
            execution_hash,
            min_vote_threshold,
            expiration_secs,
            early_resolution_vote_threshold,
            yes_votes: 0,
            no_votes: 0,
            is_resolved: false,
        });

        Event::emit_event<CreateProposalEvent>(
            &mut voting_forum.events.create_proposal_events,
            CreateProposalEvent {
                proposal_id,
                early_resolution_vote_threshold,
                execution_hash,
                expiration_secs,
                min_vote_threshold,
            },
        );

        proposal_id
    }

    /// Vote on the given proposal.
    ///
    /// @param _proof Required so only the governance module that defines ProposalType can initiate voting.
    ///               This guarantees that voting eligibility and voting power are controlled by the right governance.
    /// @param voting_forum_address The address of the forum where the proposals are stored.
    /// @param proposal_id The proposal id.
    /// @param num_votes Number of votes. Voting power should be calculated by governance.
    /// @param should_pass Whether the votes are for yes or no.
    public fun vote<ProposalType: store>(
        _proof: &ProposalType,
        voting_forum_address: address,
        proposal_id: u64,
        num_votes: u64,
        should_pass: bool,
    ) acquires VotingForum {
        let voting_forum = borrow_global_mut<VotingForum<ProposalType>>(voting_forum_address);
        let proposal = Table::borrow_mut(&mut voting_forum.proposals, proposal_id);
        if (should_pass) {
            proposal.yes_votes = proposal.yes_votes + (num_votes as u128);
        } else {
            proposal.no_votes = proposal.no_votes + (num_votes as u128);
        };

        Event::emit_event<VoteEvent>(
            &mut voting_forum.events.vote_events,
            VoteEvent { proposal_id, num_votes },
        );
    }

    /// Resolve the proposal with given id. Can only be done if there are at least as many votes as min required and
    /// there are more yes votes than no. If either of these conditions is not met, this will revert.
    ///
    /// @param voting_forum_address The address of the forum where the proposals are stored.
    /// @param proposal_id The proposal id.
    public fun resolve<ProposalType: store>(
        voting_forum_address: address,
        proposal_id: u64,
    ): ProposalType acquires VotingForum {
        let proposal_state = get_proposal_state<ProposalType>(voting_forum_address, proposal_id);
        assert!(proposal_state == PROPOSAL_STATE_SUCCEEDED, Errors::invalid_argument(EPROPOSAL_CANNOT_BE_RESOLVED));

        let voting_forum = borrow_global_mut<VotingForum<ProposalType>>(voting_forum_address);
        let proposal = Table::borrow_mut(&mut voting_forum.proposals, proposal_id);
        assert!(!proposal.is_resolved, Errors::invalid_argument(EPROPOSAL_ALREADY_RESOLVED));

        let resolved_early = can_be_resolved_early(proposal);
        proposal.is_resolved = true;

        assert!(
            TransactionContext::get_script_hash() == proposal.execution_hash,
            Errors::invalid_argument(EPROPOSAL_EXECUTION_HASH_NOT_MATCHING),
        );

        Event::emit_event<ResolveProposal>(
            &mut voting_forum.events.resolve_proposal_events,
            ResolveProposal {
                proposal_id,
                yes_votes: proposal.yes_votes,
                no_votes: proposal.no_votes,
                resolved_early,
            },
        );

        Option::extract(&mut proposal.execution_content)
    }

    /// Return true if the voting on the given proposal has already concluded.
    /// This would be the case if the proposal's expiration time has passed or if the early resolution threshold
    /// (if specified) has been reached.
    ///
    /// @param voting_forum_address The address of the forum where the proposals are stored.
    /// @param proposal_id The proposal id.
    public fun is_voting_closed<ProposalType: store>(voting_forum_address: address, proposal_id: u64): bool acquires VotingForum {
        let voting_forum = borrow_global_mut<VotingForum<ProposalType>>(voting_forum_address);
        let proposal = Table::borrow_mut(&mut voting_forum.proposals, proposal_id);
        can_be_resolved_early(proposal) || Timestamp::now_seconds() >= proposal.expiration_secs
    }

    /// Return true if the proposal has reached early resolution threshold (if specified).
    public fun can_be_resolved_early<ProposalType: store>(proposal: &Proposal<ProposalType>): bool {
        if (Option::is_some(&proposal.early_resolution_vote_threshold)) {
            let early_resolution_threshold = *Option::borrow(&proposal.early_resolution_vote_threshold);
            if (proposal.yes_votes >= early_resolution_threshold || proposal.no_votes >= early_resolution_threshold) {
                return true
            };
        };
        false
    }

    /// Return the state of the proposal with given id.
    ///
    /// @param voting_forum_address The address of the forum where the proposals are stored.
    /// @param proposal_id The proposal id.
    /// @return Proposal state as an enum value.
    public fun get_proposal_state<ProposalType: store>(
        voting_forum_address: address,
        proposal_id: u64,
    ): u64 acquires VotingForum {
        if (is_voting_closed<ProposalType>(voting_forum_address, proposal_id)) {
            let voting_forum = borrow_global<VotingForum<ProposalType>>(voting_forum_address);
            let proposal = Table::borrow(&voting_forum.proposals, proposal_id);
            let yes_votes = proposal.yes_votes;
            let no_votes = proposal.no_votes;

            if (yes_votes > no_votes && yes_votes + no_votes >= proposal.min_vote_threshold) {
                PROPOSAL_STATE_SUCCEEDED
            } else {
                PROPOSAL_STATE_FAILED
            }
        } else {
            PROPOSAL_STATE_PENDING
        }
    }

    // Return the proposal's expiration time.
    public fun get_proposal_expiration_secs<ProposalType: store>(
        voting_forum_address: address,
        proposal_id: u64,
    ): u64 acquires VotingForum {
        let voting_forum = borrow_global_mut<VotingForum<ProposalType>>(voting_forum_address);
        let proposal = Table::borrow_mut(&mut voting_forum.proposals, proposal_id);
        proposal.expiration_secs
    }

    #[test_only]
    struct TestProposal has store {}

    #[test_only]
    public fun create_test_proposal(governance: &signer, early_resolution_threshold: Option<u128>): u64 acquires VotingForum {
        // Register voting forum and create a proposal.
        register<TestProposal>(governance);
        let governance_address = Signer::address_of(governance);
        let proposal = TestProposal {};
        let proposal_id = create_proposal<TestProposal>(
            governance_address,
            proposal,
            b"",
            10,
            100000,
            early_resolution_threshold,
        );

        proposal_id
    }

    #[test(core_resources = @CoreResources, governance = @0x123)]
    public(script) fun test_voting_passed(core_resources: signer, governance: signer) acquires VotingForum {
        Timestamp::set_time_has_started_for_testing(&core_resources);

        // Register voting forum and create a proposal.
        let governance_address = Signer::address_of(&governance);
        let proposal_id = create_test_proposal(&governance, Option::none<u128>());
        assert!(get_proposal_state<TestProposal>(governance_address, proposal_id) == PROPOSAL_STATE_PENDING, 0);

        // Vote.
        let proof = TestProposal { };
        vote<TestProposal>(&proof, governance_address, proposal_id, 10, true);
        let TestProposal { } = proof;

        // Resolve.
        Timestamp::update_global_time_for_test(100001000000);
        assert!(get_proposal_state<TestProposal>(governance_address, proposal_id) == PROPOSAL_STATE_SUCCEEDED, 1);
        let proposal = resolve<TestProposal>(governance_address, proposal_id);
        let voting_forum = borrow_global<VotingForum<TestProposal>>(governance_address);
        assert!(Table::borrow(&voting_forum.proposals, proposal_id).is_resolved, 2);

        let TestProposal { } = proposal;
    }

    #[test(core_resources = @CoreResources, governance = @0x123)]
    #[expected_failure(abort_code = 775)]
    public(script) fun test_cannot_resolve_twice(core_resources: signer, governance: signer) acquires VotingForum {
        Timestamp::set_time_has_started_for_testing(&core_resources);

        // Register voting forum and create a proposal.
        let governance_address = Signer::address_of(&governance);
        let proposal_id = create_test_proposal(&governance, Option::none<u128>());
        assert!(get_proposal_state<TestProposal>(governance_address, proposal_id) == PROPOSAL_STATE_PENDING, 0);

        // Vote.
        let proof = TestProposal { };
        vote<TestProposal>(&proof, governance_address, proposal_id, 10, true);
        let TestProposal { } = proof;

        // Resolve.
        Timestamp::update_global_time_for_test(100001000000);
        assert!(get_proposal_state<TestProposal>(governance_address, proposal_id) == PROPOSAL_STATE_SUCCEEDED, 1);
        let TestProposal { } = resolve<TestProposal>(governance_address, proposal_id);

        // Resolve a second time should fail.
        let TestProposal { } = resolve<TestProposal>(governance_address, proposal_id);
    }

    #[test(core_resources = @CoreResources, governance = @0x123)]
    public(script) fun test_voting_passed_early(core_resources: signer, governance: signer) acquires VotingForum {
        Timestamp::set_time_has_started_for_testing(&core_resources);

        // Register voting forum and create a proposal.
        let governance_address = Signer::address_of(&governance);
        let proposal_id = create_test_proposal(&governance, Option::some(100));
        assert!(get_proposal_state<TestProposal>(governance_address, proposal_id) == PROPOSAL_STATE_PENDING, 0);

        // Vote.
        let proof = TestProposal { };
        vote<TestProposal>(&proof, governance_address, proposal_id, 100, true);
        vote<TestProposal>(&proof, governance_address, proposal_id, 10, false);
        let TestProposal { } = proof;

        // Resolve early.
        assert!(get_proposal_state<TestProposal>(governance_address, proposal_id) == PROPOSAL_STATE_SUCCEEDED, 1);
        let proposal = resolve<TestProposal>(governance_address, proposal_id);
        let voting_forum = borrow_global<VotingForum<TestProposal>>(governance_address);
        assert!(Table::borrow(&voting_forum.proposals, proposal_id).is_resolved, 2);

        let TestProposal { } = proposal;
    }

    #[test(core_resources = @CoreResources, governance = @0x123)]
    #[expected_failure(abort_code = 519)]
    public(script) fun test_voting_failed(core_resources: signer, governance: signer) acquires VotingForum {
        Timestamp::set_time_has_started_for_testing(&core_resources);

        // Register voting forum and create a proposal.
        let governance_address = Signer::address_of(&governance);
        let proposal_id = create_test_proposal(&governance, Option::none<u128>());

        // Vote.
        let proof = TestProposal { };
        vote<TestProposal>(&proof, governance_address, proposal_id, 10, true);
        vote<TestProposal>(&proof, governance_address, proposal_id, 100, false);
        let TestProposal { } = proof;

        // Resolve.
        Timestamp::update_global_time_for_test(100001000000);
        assert!(get_proposal_state<TestProposal>(governance_address, proposal_id) == PROPOSAL_STATE_FAILED, 1);
        let proposal = resolve<TestProposal>(governance_address, proposal_id);
        let TestProposal { } = proposal;
    }

    #[test(core_resources = @CoreResources, governance = @0x123)]
    #[expected_failure(abort_code = 519)]
    public(script) fun test_voting_failed_early(core_resources: signer, governance: signer) acquires VotingForum {
        Timestamp::set_time_has_started_for_testing(&core_resources);

        // Register voting forum and create a proposal.
        let governance_address = Signer::address_of(&governance);
        let proposal_id = create_test_proposal(&governance, Option::some(100));

        // Vote.
        let proof = TestProposal { };
        vote<TestProposal>(&proof, governance_address, proposal_id, 100, true);
        vote<TestProposal>(&proof, governance_address, proposal_id, 100, false);
        let TestProposal { } = proof;

        // Resolve.
        Timestamp::update_global_time_for_test(100001000000);
        assert!(get_proposal_state<TestProposal>(governance_address, proposal_id) == PROPOSAL_STATE_FAILED, 1);
        let proposal = resolve<TestProposal>(governance_address, proposal_id);
        let TestProposal { } = proposal;
    }
}
