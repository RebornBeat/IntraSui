module intrasui_move::community{
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::table::{Self, Table};
    use sui::bag::{Self, Bag};
    use sui::url::{Self, Url};
    use std::string::{Self, String};
    use sui::event;

    // Bounty states
    const BOUNTY_STATE_OPEN: u8 = 0;
    const BOUNTY_STATE_IN_PROGRESS: u8 = 1;
    const BOUNTY_STATE_COMPLETED: u8 = 2;
    const BOUNTY_STATE_CANCELLED: u8 = 3;

    // Ambassador states
    const AMBASSADOR_STATUS_ACTIVE: u8 = 0;
    const AMBASSADOR_STATUS_INACTIVE: u8 = 1;
    const AMBASSADOR_STATUS_SUSPENDED: u8 = 2;

    // Reputation levels
    const REPUTATION_LEVEL_NOVICE: u8 = 0;
    const REPUTATION_LEVEL_INTERMEDIATE: u8 = 1;
    const REPUTATION_LEVEL_EXPERT: u8 = 2;
    const REPUTATION_LEVEL_MASTER: u8 = 3;

    // Error codes
    const E_NOT_AUTHORIZED: u64 = 0;
    const E_INVALID_STATE: u64 = 1;
    const E_INSUFFICIENT_BALANCE: u64 = 2;
    const E_INVALID_AMOUNT: u64 = 3;
    const E_ALREADY_EXISTS: u64 = 4;
    const E_NOT_FOUND: u64 = 5;
    const E_DEADLINE_PASSED: u64 = 6;
    const E_INVALID_QUORUM: u64 = 7;

    /// Capability for minting new tokens
    public struct MintCapability has key {
        id: UID,
        cap: TreasuryCap<COMMUNITY>
    }

    /// Reputation structure
    public struct ReputationSystem has key {
        id: UID,
        users: Table<address, UserReputation>
    }

    /// User reputation structure
    public struct UserReputation has store {
        score: u64,
        level: u8,
        contributions: Table<u64, Contribution>,
        total_contributions: u64
    }

    /// Contribution structure
    public struct Contribution has store {
        activity_type: u8,
        points: u64,
        timestamp: u64,
        description: vector<u8>
    }

    /// Events
    public struct ReputationUpdatedEvent has copy, drop {
        user: address,
        new_score: u64,
        new_level: u8
    }

    /// DAO structure
    public struct DAO has key {
        id: UID,
        name: vector<u8>,
        creator: address,
        treasury: Bag,
        proposals: Table<u64, Proposal>,
        next_proposal_id: u64,
        voting_duration: u64,
        quorum: u64,
        total_supply: u64,
        members: Table<address, Member>
    }

    /// Proposal structure
    public struct Proposal has store {
        id: u64,
        creator: address,
        description: vector<u8>,
        start_time: u64,
        end_time: u64,
        yes_votes: u64,
        no_votes: u64,
        executed: bool,
        execution_data: vector<u8>
    }

    /// Member structure
    public struct Member has store {
        voting_power: u64,
        last_vote_time: u64,
        proposals_created: u64
    }

    /// Events
    public struct ProposalCreatedEvent has copy, drop {
        proposal_id: u64,
        creator: address,
        description: vector<u8>
    }

    public struct VoteCastEvent has copy, drop {
        proposal_id: u64,
        voter: address,
        in_favor: bool,
        voting_power: u64
    }

    /// Bounty structure
    public struct Bounty has key {
        id: UID,
        creator: address,
        description: vector<u8>,
        reward_amount: u64,
        status: u8,
        deadline: u64,
        assigned_to: Option<address>,
        submissions: Table<address, Submission>,
        reward_coin: Coin<COMMUNITY>
    }

    /// Submission structure
    public struct Submission has store {
        submitter: address,
        content: vector<u8>,
        timestamp: u64,
        status: u8
    }

    /// Events
    public struct BountyCreatedEvent has copy, drop {
        bounty_id: address,
        creator: address,
        reward: u64
    }

    public struct BountyCompletedEvent has copy, drop {
        bounty_id: address,
        completer: address,
        reward: u64
    }

    /// Ambassador structure
    public struct Ambassador has key {
        id: UID,
        address: address,
        profile: AmbassadorProfile,
        status: u8,
        activities: Table<u64, Activity>,
        total_activities: u64
    }

    /// Ambassador profile
    public struct AmbassadorProfile has store {
        name: vector<u8>,
        skills: vector<u8>,
        experience: u64,
        rating: u64,
        reputation_score: u64
    }

    /// Activity structure
    public struct Activity has store {
        activity_type: u8,
        timestamp: u64,
        description: vector<u8>,
        impact_score: u64
    }

    /// Events
    public struct AmbassadorRegisteredEvent has copy, drop {
        ambassador_id: address,
        name: vector<u8>
    }

    public struct ActivityRecordedEvent has copy, drop {
        ambassador_id: address,
        activity_type: u8,
        impact_score: u64
    }

    /// Registry capability - only admin can update ambassador status
    public struct AdminCap has key {
        id: UID
    }

    /// Course structure
    public struct Course has key {
        id: UID,
        name: String,
        description: String,
        content_hash: vector<u8>,
        total_modules: u64,
        required_reputation: u64,
        creator: address
    }

    /// Certificate NFT structure
    public struct Certificate has key, store {
        id: UID,
        name: String,
        description: String,
        image_url: Url,
        recipient: address,
        course_id: address,
        completion_date: u64,
        grade: u8,
        metadata: CertificateMetadata
    }

    /// Certificate metadata
    public struct CertificateMetadata has store {
        issuer: String,
        credentials: vector<u8>,
        achievements: vector<String>,
        skills_acquired: vector<String>
    }

    /// Course progress tracking
    public struct CourseProgress has key {
        id: UID,
        student: address,
        course_id: address,
        completed_modules: u64,
        current_grade: u8,
        last_activity: u64
    }

    /// Events
    public struct CourseCreatedEvent has copy, drop {
        course_id: address,
        name: String,
        creator: address
    }

    public struct CertificateIssuedEvent has copy, drop {
        certificate_id: address,
        recipient: address,
        course_id: address,
        completion_date: u64
    }

    /// Academy admin capability
    public struct AcademyCap has key {
        id: UID
    }

    /// The token type - using the proper one-time witness naming convention
    public struct COMMUNITY has drop {}

    // Main init function
    fun init(witness: COMMUNITY, ctx: &mut TxContext) {
        // Initialize token with the witness
        init_tokens(witness, ctx);

        // Initialize reputation system
        init_reputation_system(ctx);

        // Create and transfer admin capability
        transfer::transfer(
            AdminCap { id: object::new(ctx) },
            @admin
        );

        // Create and transfer academy capability
        transfer::transfer(
            AcademyCap { id: object::new(ctx) },
            @admin
        );
    }

    /// Initialize INTRA token
    fun init_tokens(witness: COMMUNITY, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency(
            witness,
            8, // decimals
            b"INTRA",
            b"IntraSui Token",
            b"Governance and utility token for IntraSui ecosystem",
            option::none(),
            ctx
        );

        transfer::public_freeze_object(metadata);
        transfer::share_object(MintCapability { id: object::new(ctx), cap: treasury_cap });
    }

    /// Mint new tokens
    public fun mint(
        cap: &mut MintCapability,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        let coin = coin::mint(&mut cap.cap, amount, ctx);
        transfer::public_transfer(coin, recipient);
    }

    /// Burn tokens
    public fun burn(
        cap: &mut MintCapability,
        coin: Coin<COMMUNITY>
    ) {
        coin::burn(&mut cap.cap, coin);
    }

    /// Transfer tokens
    public fun transfer(
        from: &mut Coin<COMMUNITY>,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        let coin = coin::split(from, amount, ctx);
        transfer::public_transfer(coin, recipient);
    }

    /// Initialize reputation system
    fun init_reputation_system(ctx: &mut TxContext) {
        let reputation_system = ReputationSystem {
            id: object::new(ctx),
            users: table::new(ctx)
        };
        transfer::share_object(reputation_system);
    }

    /// Add contribution
    public fun add_contribution(
        system: &mut ReputationSystem,
        user: address,
        points: u64,
        activity_type: u8,
        description: vector<u8>,
        ctx: &mut TxContext
    ) {
        if (!table::contains(&system.users, user)) {
            table::add(&mut system.users, user, UserReputation {
                score: 0,
                level: REPUTATION_LEVEL_NOVICE,
                contributions: table::new(ctx),
                total_contributions: 0
            });
        };

        let user_rep = table::borrow_mut(&mut system.users, user);
        user_rep.score = user_rep.score + points;

        // Add the contribution
        let contribution = Contribution {
            activity_type,
            points,
            timestamp: tx_context::epoch(ctx),
            description
        };
        table::add(&mut user_rep.contributions, user_rep.total_contributions, contribution);
        user_rep.total_contributions = user_rep.total_contributions + 1;

        // Update level
        let old_level = user_rep.level;
        update_level(user_rep);

        // Emit event if level changed
        if (old_level != user_rep.level) {
            event::emit(ReputationUpdatedEvent {
                user,
                new_score: user_rep.score,
                new_level: user_rep.level
            });
        }
    }

    /// Update user level based on score
    fun update_level(user_rep: &mut UserReputation) {
        if (user_rep.score >= 10000) {
            user_rep.level = REPUTATION_LEVEL_MASTER;
        } else if (user_rep.score >= 5000) {
            user_rep.level = REPUTATION_LEVEL_EXPERT;
        } else if (user_rep.score >= 1000) {
            user_rep.level = REPUTATION_LEVEL_INTERMEDIATE;
        };
    }

    /// Get user's reputation score
    public fun get_score(system: &ReputationSystem, user: address): u64 {
        if (!table::contains(&system.users, user)) {
            return 0
        };
        let user_rep = table::borrow(&system.users, user);
        user_rep.score
    }

    /// Get user's level
    public fun get_level(system: &ReputationSystem, user: address): u8 {
        if (!table::contains(&system.users, user)) {
            return REPUTATION_LEVEL_NOVICE
        };
        let user_rep = table::borrow(&system.users, user);
        user_rep.level
    }

    /// Create new DAO
    public fun create_dao(
        name: vector<u8>,
        voting_duration: u64,
        quorum: u64,
        ctx: &mut TxContext
    ) {
        assert!(quorum > 0 && quorum <= 100, E_INVALID_QUORUM);

        let dao = DAO {
            id: object::new(ctx),
            name,
            creator: tx_context::sender(ctx),
            treasury: bag::new(ctx),
            proposals: table::new(ctx),
            next_proposal_id: 0,
            voting_duration,
            quorum,
            total_supply: 0,
            members: table::new(ctx)
        };

        transfer::share_object(dao);
    }

    /// Create proposal
    public fun create_proposal(
        dao: &mut DAO,
        description: vector<u8>,
        execution_data: vector<u8>,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        assert!(table::contains(&dao.members, sender), E_NOT_AUTHORIZED);

        let proposal = Proposal {
            id: dao.next_proposal_id,
            creator: sender,
            description,
            start_time: tx_context::epoch(ctx),
            end_time: tx_context::epoch(ctx) + dao.voting_duration,
            yes_votes: 0,
            no_votes: 0,
            executed: false,
            execution_data
        };

        // Get the proposal ID before adding to table
        let proposal_id = proposal.id;
        let proposal_creator = proposal.creator;
        let proposal_description = proposal.description;

        table::add(&mut dao.proposals, dao.next_proposal_id, proposal);
        dao.next_proposal_id = dao.next_proposal_id + 1;

        // Emit event using the saved values
        event::emit(ProposalCreatedEvent {
            proposal_id,
            creator: proposal_creator,
            description: proposal_description
        });
    }

    /// Cast vote
    public fun vote(
        dao: &mut DAO,
        proposal_id: u64,
        in_favor: bool,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        assert!(table::contains(&dao.members, sender), E_NOT_AUTHORIZED);

        let member = table::borrow(&dao.members, sender);
        let proposal = table::borrow_mut(&mut dao.proposals, proposal_id);

        assert!(!proposal.executed, E_INVALID_STATE);
        assert!(tx_context::epoch(ctx) <= proposal.end_time, E_DEADLINE_PASSED);

        if (in_favor) {
            proposal.yes_votes = proposal.yes_votes + member.voting_power;
        } else {
            proposal.no_votes = proposal.no_votes + member.voting_power;
        };

        // Emit event
        event::emit(VoteCastEvent {
            proposal_id,
            voter: sender,
            in_favor,
            voting_power: member.voting_power
        });
    }

    /// Add member to DAO
    public fun add_member(
        dao: &mut DAO,
        member_address: address,
        voting_power: u64,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        assert!(sender == dao.creator, E_NOT_AUTHORIZED);
        assert!(!table::contains(&dao.members, member_address), E_ALREADY_EXISTS);

        table::add(&mut dao.members, member_address, Member {
            voting_power,
            last_vote_time: 0,
            proposals_created: 0
        });

        dao.total_supply = dao.total_supply + voting_power;
    }

    /// Add tokens to treasury
    public fun deposit_to_treasury(
        dao: &mut DAO,
        tokens: Coin<COMMUNITY>,
        ctx: &mut TxContext
    ) {
        let key = b"INTRA_TREASURY";

        if (!bag::contains(&dao.treasury, key)) {
            bag::add(&mut dao.treasury, key, tokens);
        } else {
            let existing = bag::borrow_mut<vector<u8>, Coin<COMMUNITY>>(&mut dao.treasury, key);
            coin::join(existing, tokens);
        }
    }

    /// Create new bounty
    public fun create_bounty(
        description: vector<u8>,
        reward: Coin<COMMUNITY>,
        deadline: u64,
        ctx: &mut TxContext
    ) {
        let bounty_id = object::new(ctx);
        let inner_id = object::uid_to_address(&bounty_id);
        let reward_amount = coin::value(&reward);

        let bounty = Bounty {
            id: bounty_id,
            creator: tx_context::sender(ctx),
            description,
            reward_amount,
            status: BOUNTY_STATE_OPEN,
            deadline,
            assigned_to: std::option::none(),
            submissions: table::new(ctx),
            reward_coin: reward
        };

        // Emit event
        event::emit(BountyCreatedEvent {
            bounty_id: inner_id,
            creator: tx_context::sender(ctx),
            reward: reward_amount
        });

        transfer::share_object(bounty);
    }

    /// Submit work for bounty
    public fun submit_work(
        bounty: &mut Bounty,
        content: vector<u8>,
        ctx: &mut TxContext
    ) {
        assert!(bounty.status == BOUNTY_STATE_OPEN, E_INVALID_STATE);
        assert!(tx_context::epoch(ctx) <= bounty.deadline, E_DEADLINE_PASSED);

        let submission = Submission {
            submitter: tx_context::sender(ctx),
            content,
            timestamp: tx_context::epoch(ctx),
            status: BOUNTY_STATE_IN_PROGRESS
        };

        table::add(&mut bounty.submissions, tx_context::sender(ctx), submission);
    }

    /// Approve submission and complete bounty
    public fun approve_submission(
        bounty: &mut Bounty,
        submitter: address,
        rep_system: &mut ReputationSystem,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == bounty.creator, E_NOT_AUTHORIZED);
        assert!(table::contains(&bounty.submissions, submitter), E_NOT_FOUND);

        bounty.status = BOUNTY_STATE_COMPLETED;

        // Send reward to submitter
        let reward = coin::split(&mut bounty.reward_coin, bounty.reward_amount, ctx);
        transfer::public_transfer(reward, submitter);

        // Update reputation with activity details
        add_contribution(
            rep_system,
            submitter,
            bounty.reward_amount / 10, // Points based on reward
            1, // Activity type for bounty completion
            bounty.description, // Using bounty description
            ctx
        );

        // Emit event
        event::emit(BountyCompletedEvent {
            bounty_id: object::uid_to_address(&bounty.id),
            completer: submitter,
            reward: bounty.reward_amount
        });
    }

    /// Cancel bounty (only creator)
    public fun cancel_bounty(
        bounty: &mut Bounty,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == bounty.creator, E_NOT_AUTHORIZED);
        assert!(bounty.status == BOUNTY_STATE_OPEN, E_INVALID_STATE);

        bounty.status = BOUNTY_STATE_CANCELLED;

        // Return funds to creator
        let refund = coin::split(&mut bounty.reward_coin, bounty.reward_amount, ctx);
        transfer::public_transfer(refund, bounty.creator);
    }

    /// Register new ambassador
    public fun register_ambassador(
        name: vector<u8>,
        skills: vector<u8>,
        rep_system: &ReputationSystem,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let rep_score = get_score(rep_system, sender);

        // Require minimum reputation score
        assert!(rep_score >= 1000, E_NOT_AUTHORIZED);

        let ambassador_id = object::new(ctx);
        let inner_id = object::uid_to_address(&ambassador_id);

        let ambassador = Ambassador {
            id: ambassador_id,
            address: sender,
            profile: AmbassadorProfile {
                name,
                skills,
                experience: 0,
                rating: 0,
                reputation_score: rep_score
            },
            status: AMBASSADOR_STATUS_ACTIVE,
            activities: table::new(ctx),
            total_activities: 0
        };

        // Emit event
        event::emit(AmbassadorRegisteredEvent {
            ambassador_id: inner_id,
            name
        });

        transfer::transfer(ambassador, sender);
    }

    /// Record ambassador activity
    public fun record_activity(
        ambassador: &mut Ambassador,
        activity_type: u8,
        description: vector<u8>,
        impact_score: u64,
        rep_system: &mut ReputationSystem,
        ctx: &mut TxContext
    ) {
        assert!(ambassador.status == AMBASSADOR_STATUS_ACTIVE, E_INVALID_STATE);
        assert!(ambassador.address == tx_context::sender(ctx), E_NOT_AUTHORIZED);

        let activity = Activity {
            activity_type,
            timestamp: tx_context::epoch(ctx),
            description,
            impact_score
        };

        table::add(&mut ambassador.activities, ambassador.total_activities, activity);
        ambassador.total_activities = ambassador.total_activities + 1;

        // Update rating based on impact
        ambassador.profile.rating = ambassador.profile.rating + impact_score;
        ambassador.profile.experience = ambassador.profile.experience + 1;

        // Update reputation
        add_contribution(
            rep_system,
            ambassador.address,
            impact_score,
            2, // Activity type for ambassador activity
            description,
            ctx
        );

        // Emit event
        event::emit(ActivityRecordedEvent {
            ambassador_id: object::uid_to_address(&ambassador.id),
            activity_type,
            impact_score
        });
    }

    /// Update ambassador status (admin only)
    public fun update_status(
        _cap: &AdminCap,
        ambassador: &mut Ambassador,
        new_status: u8,
        ctx: &mut TxContext
    ) {
        ambassador.status = new_status;
    }

    /// Get ambassador rating
    public fun get_rating(ambassador: &Ambassador): u64 {
        ambassador.profile.rating
    }

    /// Get ambassador experience
    public fun get_experience(ambassador: &Ambassador): u64 {
        ambassador.profile.experience
    }

    /// Create new course (admin only)
    public fun create_course(
        _cap: &AcademyCap,
        name: vector<u8>,
        description: vector<u8>,
        content_hash: vector<u8>,
        total_modules: u64,
        required_reputation: u64,
        ctx: &mut TxContext
    ) {
        let course_id = object::new(ctx);
        let inner_id = object::uid_to_address(&course_id);
        let creator = tx_context::sender(ctx);

        let name_str = string::utf8(name);

        let course = Course {
            id: course_id,
            name: name_str,
            description: string::utf8(description),
            content_hash,
            total_modules,
            required_reputation,
            creator
        };

        // Emit event
        event::emit(CourseCreatedEvent {
            course_id: inner_id,
            name: name_str,
            creator
        });

        transfer::share_object(course);
    }

    /// Start course
    public fun start_course(
        course: &Course,
        rep_system: &ReputationSystem,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let rep_score = get_score(rep_system, sender);

        // Check reputation requirement
        assert!(rep_score >= course.required_reputation, E_NOT_AUTHORIZED);

        let progress = CourseProgress {
            id: object::new(ctx),
            student: sender,
            course_id: object::uid_to_address(&course.id),
            completed_modules: 0,
            current_grade: 0,
            last_activity: tx_context::epoch(ctx)
        };

        transfer::transfer(progress, sender);
    }

    /// Update course progress
    public fun update_progress(
        progress: &mut CourseProgress,
        completed_modules: u64,
        grade: u8,
        ctx: &mut TxContext
    ) {
        assert!(progress.student == tx_context::sender(ctx), E_NOT_AUTHORIZED);

        progress.completed_modules = completed_modules;
        progress.current_grade = grade;
        progress.last_activity = tx_context::epoch(ctx);
    }

    /// Issue certificate (admin only)
    public fun issue_certificate(
        _cap: &AcademyCap,
        course: &Course,
        progress: &CourseProgress,
        grade: u8,
        achievements: vector<String>,
        skills: vector<String>,
        rep_system: &mut ReputationSystem,
        ctx: &mut TxContext
    ) {
        // Verify course completion
        assert!(progress.completed_modules == course.total_modules, E_INVALID_STATE);
        assert!(progress.course_id == object::uid_to_address(&course.id), E_INVALID_STATE);

        let certificate_id = object::new(ctx);
        let inner_id = object::uid_to_address(&certificate_id);
        let completion_date = tx_context::epoch(ctx);

        let certificate = Certificate {
            id: certificate_id,
            name: string::utf8(b"IntraSui Academy Certificate"),
            description: course.name,
            image_url: url::new_unsafe_from_bytes(b"https://intrasui.io/certificates/"),
            recipient: progress.student,
            course_id: object::uid_to_address(&course.id),
            completion_date,
            grade,
            metadata: CertificateMetadata {
                issuer: string::utf8(b"IntraSui Academy"),
                credentials: vector::empty(),
                achievements,
                skills_acquired: skills
            }
        };

        // Update student reputation
        add_contribution(
            rep_system,
            progress.student,
            2000, // Significant points for completing a course
            3,    // Activity type for course completion
            *string::bytes(&course.name),
            ctx
        );

        // Emit event
        event::emit(CertificateIssuedEvent {
            certificate_id: inner_id,
            recipient: progress.student,
            course_id: object::uid_to_address(&course.id),
            completion_date
        });

        transfer::transfer(certificate, progress.student);
    }

    /// Verify certificate
    public fun verify_certificate(certificate: &Certificate): bool {
        // Add verification logic here
        true
    }

    /// Get certificate details
    public fun get_certificate_details(certificate: &Certificate): (String, address, address, u64, u8) {
        (
            certificate.name,
            certificate.recipient,
            certificate.course_id,
            certificate.completion_date,
            certificate.grade
        )
    }
}
