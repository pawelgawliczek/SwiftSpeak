//
//  Context.swift
//  SwiftSpeak
//
//  Conversation context and memory models
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakKeyboard targets
//

import Foundation

// MARK: - Enter Key Behavior

/// What happens when Enter key is pressed in keyboard
public enum EnterKeyBehavior: String, Codable, CaseIterable, Identifiable {
    case defaultNewLine = "newLine"       // Normal enter = new line
    case formatThenInsert = "format"      // Enter = format with context, then insert (don't send)
    case justSend = "send"                // Enter = just send (no formatting)
    case formatAndSend = "formatSend"     // Enter = format with context, insert, then send

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .defaultNewLine: return "New line"
        case .formatThenInsert: return "Format + insert"
        case .justSend: return "Send"
        case .formatAndSend: return "Format + send"
        }
    }

    public var description: String {
        switch self {
        case .defaultNewLine: return "Enter creates a new line (default keyboard behavior)"
        case .formatThenInsert: return "Format text with this context, then insert it"
        case .justSend: return "Send the message immediately"
        case .formatAndSend: return "Format text with this context, insert, then send"
        }
    }

    public var icon: String {
        switch self {
        case .defaultNewLine: return "return"
        case .formatThenInsert: return "text.badge.checkmark"
        case .justSend: return "paperplane"
        case .formatAndSend: return "paperplane.fill"
        }
    }
}

// MARK: - Formatting Instruction

/// A toggleable formatting instruction (chip)
/// Grouped by how invasive they are to the original text
public struct FormattingInstruction: Codable, Identifiable, Hashable {
    public let id: String
    public let displayName: String
    public let promptText: String
    public let group: InstructionGroup
    public let icon: String?

    public enum InstructionGroup: String, Codable, CaseIterable {
        case lightTouch = "light"    // Preserves words: punctuation, capitals, spelling
        case grammar = "grammar"      // May adjust phrasing
        case style = "style"          // Will rephrase as needed
        case emoji = "emoji"          // Emoji usage level
    }

    /// All available formatting instructions
    public static let all: [FormattingInstruction] = [
        // Light touch - preserves your words
        FormattingInstruction(
            id: "punctuation",
            displayName: "Punctuation",
            promptText: "Fix punctuation (periods, commas, apostrophes).",
            group: .lightTouch,
            icon: "textformat"
        ),
        FormattingInstruction(
            id: "capitals",
            displayName: "Capitals",
            promptText: "Fix capitalization (sentence starts, proper nouns).",
            group: .lightTouch,
            icon: "textformat.size"
        ),
        FormattingInstruction(
            id: "spelling",
            displayName: "Spelling",
            promptText: "Fix spelling mistakes.",
            group: .lightTouch,
            icon: "character.cursor.ibeam"
        ),

        // Grammar - may adjust phrasing
        FormattingInstruction(
            id: "grammar",
            displayName: "Grammar",
            promptText: "Fix grammar errors. You may slightly rephrase awkward constructions.",
            group: .grammar,
            icon: "text.badge.checkmark"
        ),

        // Style - will rephrase as needed
        FormattingInstruction(
            id: "casual",
            displayName: "Casual",
            promptText: "Use a casual, friendly tone. Rephrase to sound conversational.",
            group: .style,
            icon: "face.smiling"
        ),
        FormattingInstruction(
            id: "formal",
            displayName: "Formal",
            promptText: "Use a formal, professional tone. Rephrase to sound business-appropriate.",
            group: .style,
            icon: "briefcase"
        ),
        FormattingInstruction(
            id: "concise",
            displayName: "Concise",
            promptText: "Make it concise. Remove filler words and unnecessary phrases.",
            group: .style,
            icon: "arrow.down.right.and.arrow.up.left"
        ),
        FormattingInstruction(
            id: "bullets",
            displayName: "Bullets",
            promptText: "Format as bullet points where appropriate.",
            group: .style,
            icon: "list.bullet"
        ),

        // Emoji levels (mutually exclusive)
        FormattingInstruction(
            id: "emoji_never",
            displayName: "Never",
            promptText: "Do NOT add any emoji.",
            group: .emoji,
            icon: "xmark.circle"
        ),
        FormattingInstruction(
            id: "emoji_few",
            displayName: "Few",
            promptText: "Add emoji sparingly, only where they enhance the message.",
            group: .emoji,
            icon: "face.smiling"
        ),
        FormattingInstruction(
            id: "emoji_lots",
            displayName: "Lots",
            promptText: "Add emoji generously throughout the message.",
            group: .emoji,
            icon: "sparkles"
        )
    ]

    /// Get instructions by group
    public static func instructions(for group: InstructionGroup) -> [FormattingInstruction] {
        all.filter { $0.group == group }
    }

    /// Get instruction by ID
    public static func instruction(withId id: String) -> FormattingInstruction? {
        all.first { $0.id == id }
    }

    /// Group display info
    public static func groupInfo(_ group: InstructionGroup) -> (title: String, subtitle: String, icon: String) {
        switch group {
        case .lightTouch:
            return ("Light touch", "Preserves your words", "📝")
        case .grammar:
            return ("Grammar", "May adjust phrasing", "✏️")
        case .style:
            return ("Style", "Will rephrase as needed", "🎨")
        case .emoji:
            return ("Emoji", "Emoji usage level", "😊")
        }
    }
}

// MARK: - Domain Jargon Type

/// Domain-specific vocabulary hints for transcription accuracy
/// When enabled, Whisper and other STT providers receive domain hints
/// to improve recognition of technical terminology
public enum DomainJargon: String, Codable, CaseIterable, Identifiable {
    case none = "none"              // No specific domain
    case medical = "medical"        // Healthcare, pharmaceutical, clinical terms
    case legal = "legal"            // Law, contracts, litigation terminology
    case technical = "technical"    // Software, engineering, IT terms
    case financial = "financial"    // Banking, investment, accounting terms
    case scientific = "scientific"  // Research, laboratory, academic terms
    case business = "business"      // Corporate, management, strategy terms
    case marketing = "marketing"    // Advertising, campaigns, branding terms
    case realEstate = "realEstate"  // Property, mortgage, listings terms
    case hr = "hr"                  // Human resources, recruiting, benefits terms
    case insurance = "insurance"    // Coverage, claims, underwriting terms
    case construction = "construction"  // Building, architecture, engineering terms
    case education = "education"    // Academic, teaching, curriculum terms

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .none: return "None"
        case .medical: return "Medical"
        case .legal: return "Legal"
        case .technical: return "Technical"
        case .financial: return "Financial"
        case .scientific: return "Scientific"
        case .business: return "Business"
        case .marketing: return "Marketing"
        case .realEstate: return "Real Estate"
        case .hr: return "HR"
        case .insurance: return "Insurance"
        case .construction: return "Construction"
        case .education: return "Education"
        }
    }

    public var description: String {
        switch self {
        case .none: return "No domain-specific vocabulary hints"
        case .medical: return "Medical, pharmaceutical, and clinical terminology"
        case .legal: return "Legal, contracts, and litigation terminology"
        case .technical: return "Software, engineering, and IT terminology"
        case .financial: return "Banking, investment, and accounting terminology"
        case .scientific: return "Research, laboratory, and academic terminology"
        case .business: return "Corporate, management, and strategy terminology"
        case .marketing: return "Advertising, campaigns, and branding terminology"
        case .realEstate: return "Property, mortgage, and listings terminology"
        case .hr: return "Recruiting, benefits, and employee management terminology"
        case .insurance: return "Coverage, claims, and underwriting terminology"
        case .construction: return "Building, architecture, and project management terminology"
        case .education: return "Academic, teaching, and curriculum terminology"
        }
    }

    public var icon: String {
        switch self {
        case .none: return "text.bubble"
        case .medical: return "cross.case.fill"
        case .legal: return "building.columns.fill"
        case .technical: return "chevron.left.forwardslash.chevron.right"
        case .financial: return "chart.line.uptrend.xyaxis"
        case .scientific: return "atom"
        case .business: return "briefcase.fill"
        case .marketing: return "megaphone.fill"
        case .realEstate: return "house.fill"
        case .hr: return "person.2.fill"
        case .insurance: return "shield.fill"
        case .construction: return "hammer.fill"
        case .education: return "graduationcap.fill"
        }
    }

    /// Whisper prompt hint for this domain
    /// Provides examples of expected vocabulary to improve recognition
    /// Each domain includes 40-60 industry-specific terms plus acronyms
    public var transcriptionHint: String? {
        switch self {
        case .none:
            return nil
        case .medical:
            // Medical terms + acronyms (MRI, CT, ECG, EKG, IV, IM, SC, PO, PRN, BID, TID, QID, STAT, NPO, DNR, etc.)
            return "Medical terminology: diagnosis, prognosis, prescription, symptoms, treatment, dosage, mg, ml, patient, procedure, surgery, medication, chronic, acute, pathology, radiology, oncology, cardiology, neurology, orthopedic, pediatric, geriatric, anesthesia, biopsy, vital signs, blood pressure, pulse, respiration, antibiotic, analgesic, sedative, comorbidity, contraindication, adverse reaction, clinical trial, placebo, differential diagnosis. Acronyms: MRI, CT, PET, ECG, EKG, EEG, EMG, IV, IM, SC, PO, PRN, BID, TID, QID, STAT, NPO, DNR, DNI, CPR, AED, ICU, ER, OR, PACU, OB-GYN, ENT, GI, CVS, CNS, BP, HR, SpO2, BMI, CBC, BMP, CMP, LFT, TSH, A1C, HDL, LDL, PSA, AFP, HCG, HIPAA, EMR, EHR, PHI, CDC, FDA, WHO, NIH"
        case .legal:
            // Legal terms + acronyms (NDA, IP, LLC, LLP, JD, ESQ, POA, UCC, ADA, EEOC, etc.)
            return "Legal terminology: plaintiff, defendant, litigation, contract, clause, jurisdiction, statute, liability, damages, settlement, affidavit, deposition, subpoena, injunction, arbitration, mediation, tort, negligence, breach, indemnity, fiduciary, escrow, power of attorney, pro bono, amicus curiae, habeas corpus, precedent, appellant, appellee, motion, discovery, interrogatories, stipulation, waiver, amendment, notarized, executor, beneficiary, intestate, probate, lien, encumbrance, due diligence, confidentiality. Acronyms: NDA, IP, LLC, LLP, LP, INC, CORP, JD, ESQ, POA, UCC, ADA, EEOC, OSHA, SEC, FTC, DOJ, SCOTUS, FOIA, CFPB, ERISA, SOX, FCPA, GDPR, CCPA, TRO, RFP, MOU, LOI, MSA, SLA, TOS, EULA, ADR, AAA, JAMS, ALJ, AG, DA, PD, ABA, CLE"
        case .technical:
            // Tech terms + acronyms (API, SDK, REST, GraphQL, CI/CD, AWS, GCP, K8s, SQL, NoSQL, etc.)
            return "Technical terminology: database, server, deployment, repository, commit, merge, branch, function, variable, algorithm, framework, backend, frontend, microservices, containerization, authentication, authorization, encryption, endpoint, webhook, callback, async, await, promise, thread, process, memory, cache, latency, throughput, scalability, redundancy, load balancer. Acronyms: API, SDK, REST, GraphQL, JSON, XML, YAML, HTML, CSS, JS, TS, SQL, NoSQL, OAuth, JWT, SSL, TLS, HTTPS, SSH, FTP, SFTP, TCP, UDP, IP, DNS, CDN, VPN, VPC, AWS, GCP, Azure, EC2, S3, RDS, EKS, GKE, AKS, K8s, CI/CD, DevOps, SRE, MLOps, IaC, CRUD, ORM, MVC, MVVM, IDE, CLI, GUI, UI, UX, QA, UAT, SLA, SLO, SLI, APM, RUM, ELK, SIEM"
        case .financial:
            // Financial terms + acronyms (ROI, EBITDA, P&L, APR, APY, ETF, SEC, GAAP, IFRS, etc.)
            return "Financial terminology: portfolio, equity, dividend, revenue, margin, valuation, amortization, depreciation, accrual, cash flow, liquidity, solvency, leverage, capital gains, yield, compound interest, hedge, derivative, futures, options, securities, bonds, mutual fund, fiduciary, custodian, escrow, audit, reconciliation, ledger, receivables, payables, overhead, gross profit, net income, breakeven, forecast, budget variance. Acronyms: ROI, ROE, ROA, EBITDA, EBIT, P&L, P/E, EPS, NAV, AUM, APR, APY, YTD, YOY, QOQ, MOM, ETF, IPO, M&A, LBO, MBO, VC, PE, DCF, NPV, IRR, WACC, CAPM, GAAP, IFRS, SEC, FINRA, FDIC, SIPC, CFTC, OCC, FASB, CPA, CFP, CFA, CFO, CEO, COO, CAO, 401k, IRA, HSA, FSA, W2, 1099, K1, FICO"
        case .scientific:
            // Scientific terms + acronyms (PhD, PI, IRB, NIH, NSF, DOI, ANOVA, PCR, DNA, RNA, etc.)
            return "Scientific terminology: hypothesis, methodology, analysis, experiment, results, conclusion, peer-reviewed, statistical, correlation, causation, variable, control group, sample size, significance, standard deviation, mean, median, regression, outlier, replication, validity, reliability, bias, protocol, literature review, abstract, citation, journal, publication, thesis, dissertation, principal investigator, grant, ethics, informed consent, longitudinal, cross-sectional, qualitative, quantitative, meta-analysis, systematic review. Acronyms: PhD, PI, RA, TA, IRB, NIH, NSF, DOE, NASA, CDC, WHO, FDA, EPA, USDA, DOI, PMID, ANOVA, t-test, ANCOVA, MANOVA, SEM, PCA, ICA, DNA, RNA, mRNA, PCR, qPCR, CRISPR, ELISA, WB, IF, IHC, NMR, MS, LC, GC, HPLC, SDS-PAGE, GDP, GTP, ATP, ADP, BSA, PBS, DMSO, EDTA, UV, IR"
        case .business:
            // Business terms + acronyms (KPI, OKR, ROI, B2B, B2C, SaaS, CRM, ERP, MBA, etc.)
            return "Business terminology: stakeholder, deliverable, roadmap, synergy, quarterly, strategy, initiative, metrics, pipeline, bandwidth, leverage, scalable, actionable, ecosystem, pivot, innovate, optimize, streamline, onboarding, retention, acquisition, churn, conversion, funnel, touchpoint, customer journey, value proposition, competitive advantage, market share, milestone, cross-functional, alignment, due diligence. Acronyms: KPI, OKR, ROI, ROE, CAGR, TAM, SAM, SOM, GTM, PMF, MVP, POC, NPS, CSAT, CLV, LTV, CAC, ARR, MRR, GMV, AOV, B2B, B2C, D2C, SaaS, PaaS, IaaS, CRM, ERP, HCM, SCM, WMS, TMS, BI, AI, ML, RPA, IoT, API, SDK, UX, UI, SEO, SEM, PPC, CPC, CPM, CTR, CRO, ABM, MQL, SQL, MBA, CEO, CFO, COO, CTO, CMO, CRO, CPO, CHRO, VP, SVP, EVP, C-suite"
        case .marketing:
            // Marketing terms + acronyms (SEO, SEM, PPC, CPC, CTR, ROI, CRM, etc.)
            return "Marketing terminology: campaign, branding, positioning, segmentation, targeting, persona, audience, impression, engagement, reach, virality, influencer, content marketing, inbound, outbound, lead generation, nurturing, attribution, retargeting, remarketing, affiliate, sponsorship, endorsement, creative, copy, headline, call-to-action, landing page, conversion, A/B testing, multivariate, cohort, funnel, pipeline, lifecycle, awareness, consideration, decision, loyalty, advocacy. Acronyms: SEO, SEM, PPC, CPC, CPM, CPA, CPL, CTR, CVR, CRO, ROI, ROAS, AOV, CLV, LTV, CAC, MQL, SQL, SAL, DMP, DSP, SSP, RTB, OTT, CTV, OOH, DOOH, PR, UGC, CGM, SMM, SMO, KOL, B2B, B2C, D2C, CRM, CDP, ESP, MAP, ABM, GTM, PMM, CMO, VP, MARCOM, IMC, STP"
        case .realEstate:
            // Real estate terms + acronyms (MLS, HOA, FHA, VA, ARM, PMI, etc.)
            return "Real estate terminology: listing, closing, escrow, title, deed, mortgage, refinance, appraisal, inspection, contingency, earnest money, down payment, principal, interest, amortization, equity, appreciation, depreciation, foreclosure, short sale, lien, encumbrance, easement, covenant, zoning, variance, permit, occupancy, tenant, landlord, lease, sublease, eviction, security deposit, rent roll, cap rate, cash flow, NOI, gross rent multiplier. Acronyms: MLS, HOA, CC&R, FHA, VA, USDA, ARM, PMI, LTV, DTI, APR, PITI, HUD, RESPA, TILA, TRID, CMA, BPO, AVM, REO, FSBO, POA, COE, PSA, NDA, LOI, ROI, NOI, GRM, IRR, CAM, NNN, TI, SFR, MFR, CRE, NNN, TIC, REIT, 1031, DST, QOZ"
        case .hr:
            // HR terms + acronyms (HRIS, ATS, PTO, FMLA, COBRA, EEO, etc.)
            return "HR terminology: recruitment, onboarding, offboarding, retention, attrition, turnover, headcount, FTE, contractor, temp, intern, exempt, non-exempt, compensation, benefits, equity, vesting, cliff, bonus, commission, incentive, performance review, appraisal, feedback, coaching, mentoring, succession planning, talent management, workforce planning, diversity, inclusion, belonging, culture, engagement, satisfaction, wellness, ergonomics, harassment, discrimination, grievance, termination, severance, outplacement. Acronyms: HRIS, HCM, ATS, LMS, PTO, FMLA, COBRA, ADA, EEO, EEOC, OSHA, DOL, FLSA, I-9, W-4, W-2, 1099, 401k, HSA, FSA, HRA, ESOP, RSU, ISO, NSO, OTE, MBO, KPI, OKR, NPS, eNPS, CHRO, VP, HR, TA, L&D, D&I, DEI, ERG, BU, CoE, HRBP, PHR, SPHR, SHRM-CP, SHRM-SCP"
        case .insurance:
            // Insurance terms + acronyms (HMO, PPO, EPO, POS, HSA, FSA, etc.)
            return "Insurance terminology: policy, premium, deductible, copay, coinsurance, coverage, exclusion, rider, endorsement, beneficiary, insured, underwriting, actuarial, risk assessment, claim, adjuster, settlement, liability, indemnity, subrogation, reinsurance, captive, self-insured, loss ratio, combined ratio, reserves, surplus, solvency, rating, classification, experience modification, retrospective, occurrence, claims-made, aggregate, per-occurrence, umbrella, excess, binder, certificate, declarations, conditions, definitions. Acronyms: HMO, PPO, EPO, POS, HSA, FSA, HRA, COBRA, ACA, HIPAA, CMS, Medicare, Medicaid, CHIP, ERISA, DOL, NAIC, A.M. Best, S&P, Moody's, P&C, L&H, GL, PL, E&O, D&O, BOP, WC, UI, LTD, STD, AD&D, EPLI, HNWI, ACV, RCV, ERC, MOB, TPA, MGA, MGU, CSR, CPCU, CLU, ChFC"
        case .construction:
            // Construction terms + acronyms (GC, HVAC, MEP, BIM, LEED, AIA, etc.)
            return "Construction terminology: foundation, framing, drywall, roofing, siding, insulation, electrical, plumbing, concrete, rebar, formwork, excavation, grading, demolition, renovation, retrofit, punch list, substantial completion, certificate of occupancy, change order, RFI, submittal, shop drawing, specification, blueprint, elevation, section, detail, schedule, bid, estimate, takeoff, value engineering, critical path, milestone, float, lag, lead, predecessor, successor, resource leveling, progress payment, retainage, lien waiver. Acronyms: GC, CM, PM, PE, RA, AIA, LEED, OSHA, EPA, ADA, IBC, IRC, NEC, UPC, ASHRAE, HVAC, MEP, BIM, CAD, VDC, IPD, DB, DBB, CMAR, JOC, IDIQ, GMP, T&M, FFP, CPFF, NTP, NTE, RFP, RFQ, RFI, ASI, CO, PCO, COR, CPM, WBS, OBS, RBS, CBS, SOV, AIA G702, AIA G703"
        case .education:
            // Education terms + acronyms (GPA, SAT, ACT, AP, IB, STEM, IEP, etc.)
            return "Education terminology: curriculum, syllabus, pedagogy, andragogy, assessment, evaluation, rubric, grading, transcript, credit, semester, quarter, trimester, lecture, seminar, lab, practicum, internship, thesis, dissertation, capstone, prerequisite, corequisite, elective, major, minor, concentration, degree, diploma, certificate, accreditation, matriculation, enrollment, registration, admission, retention, graduation, commencement, tenure, adjunct, faculty, dean, provost, chancellor, superintendent, principal. Acronyms: GPA, SAT, ACT, GRE, GMAT, LSAT, MCAT, AP, IB, STEM, STEAM, PBL, SEL, UDL, IEP, 504, IDEA, FERPA, FAFSA, EFC, COA, Pell, PLUS, TEACH, TFA, NCATE, CAEP, ABET, AACSB, HLC, WASC, SACS, NWCCU, MSCHE, NECHE, K-12, EC, ESL, ELL, TESOL, EdD, PhD, MEd, MAT, BA, BS, MA, MS, MBA, JD, MD"
        }
    }
}

// MARK: - Conversation Context

/// A named context that customizes formatting, memory, and keyboard behavior
public struct ConversationContext: Codable, Identifiable, Equatable, Hashable {
    // MARK: - Identity
    public let id: UUID
    public var name: String                        // "Work", "Personal", "Family"
    public var icon: String                        // Emoji or SF Symbol
    public var color: PowerModeColorPreset
    public var description: String                 // Short description for list view

    // MARK: - Transcription
    public var domainJargon: DomainJargon          // Domain vocabulary hints for Whisper
    public var customJargon: [String]              // User-defined jargon words for this context

    // MARK: - Formatting
    public var examples: [String]                  // Few-shot examples (HIGHEST priority)
    public var selectedInstructions: Set<String>   // IDs of selected formatting chips
    public var customInstructions: String?         // Free-form additional instructions

    // MARK: - Memory
    public var useGlobalMemory: Bool               // Include global memory in prompts
    public var useContextMemory: Bool              // Include context-specific memory
    public var contextMemory: String?              // The stored memory content
    public var memoryLimit: Int                    // Character limit for context memory (500-2000)
    public var lastMemoryUpdate: Date?

    // MARK: - Keyboard Behavior
    public var autoSendAfterInsert: Bool           // Auto-tap send after voice input
    public var enterKeyBehavior: EnterKeyBehavior  // What Enter key does

    // MARK: - Language Settings
    public var defaultInputLanguage: Language?     // Override system dictation language (nil = auto)

    // MARK: - System
    public var isActive: Bool                      // Currently selected context
    public var appAssignment: AppAssignment        // Apps that auto-enable this context
    public var isPreset: Bool                      // Preset contexts (free tier)
    public let createdAt: Date
    public var updatedAt: Date

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        color: PowerModeColorPreset,
        description: String,
        domainJargon: DomainJargon = .none,
        customJargon: [String] = [],
        examples: [String] = [],
        selectedInstructions: Set<String> = [],
        customInstructions: String? = nil,
        useGlobalMemory: Bool = true,
        useContextMemory: Bool = false,
        contextMemory: String? = nil,
        memoryLimit: Int = 2000,
        lastMemoryUpdate: Date? = nil,
        autoSendAfterInsert: Bool = false,
        enterKeyBehavior: EnterKeyBehavior = .defaultNewLine,
        defaultInputLanguage: Language? = nil,
        isActive: Bool = false,
        appAssignment: AppAssignment = AppAssignment(),
        isPreset: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.description = description
        self.domainJargon = domainJargon
        self.customJargon = customJargon
        self.examples = examples
        self.selectedInstructions = selectedInstructions
        self.customInstructions = customInstructions
        self.useGlobalMemory = useGlobalMemory
        self.useContextMemory = useContextMemory
        self.contextMemory = contextMemory
        self.memoryLimit = memoryLimit
        self.lastMemoryUpdate = lastMemoryUpdate
        self.autoSendAfterInsert = autoSendAfterInsert
        self.enterKeyBehavior = enterKeyBehavior
        self.defaultInputLanguage = defaultInputLanguage
        self.isActive = isActive
        self.appAssignment = appAssignment
        self.isPreset = isPreset
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Computed Properties

    /// Whether any formatting is enabled (examples, instructions, or custom)
    public var hasFormatting: Bool {
        !examples.isEmpty || !selectedInstructions.isEmpty ||
        (customInstructions?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
    }

    /// Get the selected FormattingInstruction objects
    public var formattingInstructions: [FormattingInstruction] {
        selectedInstructions.compactMap { FormattingInstruction.instruction(withId: $0) }
    }

    /// Extract vocabulary words for transcription word boost
    /// Combines custom jargon, domain jargon terms, and context name
    /// Used by meeting transcription to improve recognition accuracy
    public var transcriptionVocabulary: [String] {
        var words: [String] = []

        // Add custom jargon words first (highest priority)
        words.append(contentsOf: customJargon.filter { !$0.isEmpty })

        // Extract vocabulary from domain jargon hint
        if let hint = domainJargon.transcriptionHint {
            // Hint format: "Domain terminology: word1, word2, word3..."
            // Extract words after the colon
            if let colonIndex = hint.firstIndex(of: ":") {
                let wordsPart = hint[hint.index(after: colonIndex)...]
                let extractedWords = wordsPart
                    .components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                words.append(contentsOf: extractedWords)
            }
        }

        // Also add context name as a vocabulary hint
        if !name.isEmpty {
            words.append(name)
        }

        return words
    }

    // MARK: - Static Properties

    public static var empty: ConversationContext {
        ConversationContext(
            name: "",
            icon: "person.circle",
            color: .blue,
            description: ""
        )
    }

    /// Preset contexts available to ALL users (including free tier)
    /// These have fixed UUIDs so they can be identified consistently
    public static var presets: [ConversationContext] {
        [
            ConversationContext(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                name: "Work",
                icon: "💼",
                color: .blue,
                description: "Professional business communication",
                domainJargon: .business,
                examples: [
                    "Hi John,\n\nThanks for the update. I'll review it by Friday.\n\nBest regards",
                    "Hi Sarah,\n\nCould we reschedule to 3pm? Let me know.\n\nBest regards"
                ],
                selectedInstructions: ["punctuation", "capitals", "grammar", "formal", "emoji_never"],
                useGlobalMemory: true,
                isPreset: true
            ),
            ConversationContext(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                name: "Personal",
                icon: "😊",
                color: .green,
                description: "Casual, friendly conversations",
                examples: [
                    "Hey! How's it going? 😊",
                    "Thanks for letting me know! See you soon 👍"
                ],
                selectedInstructions: ["punctuation", "grammar", "casual", "emoji_few"],
                useGlobalMemory: true,
                isPreset: true
            ),
            ConversationContext(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                name: "Creative",
                icon: "✨",
                color: .purple,
                description: "Creative writing and brainstorming",
                selectedInstructions: ["punctuation", "spelling"],
                customInstructions: "Preserve creative expression. Use expressive punctuation like em dashes and ellipses where appropriate.",
                useGlobalMemory: true,
                isPreset: true
            )
        ]
    }

    // MARK: - Codable (Backward Compatible)

    private enum CodingKeys: String, CodingKey {
        case id, name, icon, color, description
        case domainJargon, customJargon, examples, selectedInstructions, customInstructions
        case useGlobalMemory, useContextMemory, contextMemory, memoryLimit, lastMemoryUpdate
        case autoSendAfterInsert, enterKeyBehavior, defaultInputLanguage
        case isActive, appAssignment, isPreset, createdAt, updatedAt
        // Legacy
        case systemPrompt  // Migrate to customInstructions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        icon = try container.decode(String.self, forKey: .icon)
        color = try container.decode(PowerModeColorPreset.self, forKey: .color)
        description = try container.decode(String.self, forKey: .description)
        domainJargon = try container.decodeIfPresent(DomainJargon.self, forKey: .domainJargon) ?? .none
        customJargon = try container.decodeIfPresent([String].self, forKey: .customJargon) ?? []
        examples = try container.decodeIfPresent([String].self, forKey: .examples) ?? []
        selectedInstructions = try container.decodeIfPresent(Set<String>.self, forKey: .selectedInstructions) ?? []

        // Migrate systemPrompt to customInstructions if present
        if let systemPrompt = try container.decodeIfPresent(String.self, forKey: .systemPrompt) {
            customInstructions = try container.decodeIfPresent(String.self, forKey: .customInstructions) ?? systemPrompt
        } else {
            customInstructions = try container.decodeIfPresent(String.self, forKey: .customInstructions)
        }

        useGlobalMemory = try container.decodeIfPresent(Bool.self, forKey: .useGlobalMemory) ?? true
        useContextMemory = try container.decodeIfPresent(Bool.self, forKey: .useContextMemory) ?? false
        contextMemory = try container.decodeIfPresent(String.self, forKey: .contextMemory)
        // Default memoryLimit for existing contexts without the field
        memoryLimit = try container.decodeIfPresent(Int.self, forKey: .memoryLimit) ?? 2000
        lastMemoryUpdate = try container.decodeIfPresent(Date.self, forKey: .lastMemoryUpdate)

        autoSendAfterInsert = try container.decodeIfPresent(Bool.self, forKey: .autoSendAfterInsert) ?? false
        enterKeyBehavior = try container.decodeIfPresent(EnterKeyBehavior.self, forKey: .enterKeyBehavior) ?? .defaultNewLine
        defaultInputLanguage = try container.decodeIfPresent(Language.self, forKey: .defaultInputLanguage)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
        appAssignment = try container.decodeIfPresent(AppAssignment.self, forKey: .appAssignment) ?? AppAssignment()
        isPreset = try container.decodeIfPresent(Bool.self, forKey: .isPreset) ?? false
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(icon, forKey: .icon)
        try container.encode(color, forKey: .color)
        try container.encode(description, forKey: .description)
        try container.encode(domainJargon, forKey: .domainJargon)
        try container.encode(customJargon, forKey: .customJargon)
        try container.encode(examples, forKey: .examples)
        try container.encode(selectedInstructions, forKey: .selectedInstructions)
        try container.encodeIfPresent(customInstructions, forKey: .customInstructions)
        try container.encode(useGlobalMemory, forKey: .useGlobalMemory)
        try container.encode(useContextMemory, forKey: .useContextMemory)
        try container.encodeIfPresent(contextMemory, forKey: .contextMemory)
        try container.encode(memoryLimit, forKey: .memoryLimit)
        try container.encodeIfPresent(lastMemoryUpdate, forKey: .lastMemoryUpdate)
        try container.encode(autoSendAfterInsert, forKey: .autoSendAfterInsert)
        try container.encode(enterKeyBehavior, forKey: .enterKeyBehavior)
        try container.encodeIfPresent(defaultInputLanguage, forKey: .defaultInputLanguage)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(appAssignment, forKey: .appAssignment)
        try container.encode(isPreset, forKey: .isPreset)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    /// Sample contexts for previews and testing
    public static var samples: [ConversationContext] {
        [
            ConversationContext(
                name: "Wife",
                icon: "💕",
                color: .pink,
                description: "Casual, loving messages",
                examples: [
                    "Hey love! 💕 Just thinking about you",
                    "Miss you! Can't wait to see you tonight 😘"
                ],
                selectedInstructions: ["punctuation", "casual", "emoji_lots"],
                useGlobalMemory: true,
                useContextMemory: true,
                contextMemory: "Planning dinner for Friday. She prefers Italian food.",
                lastMemoryUpdate: Date().addingTimeInterval(-3600),
                isActive: true
            ),
            ConversationContext(
                name: "Tech Lead",
                icon: "👨‍💻",
                color: .blue,
                description: "Technical discussions",
                domainJargon: .technical,
                selectedInstructions: ["punctuation", "capitals", "grammar", "formal", "concise", "emoji_never"],
                useGlobalMemory: true,
                useContextMemory: true,
                contextMemory: "Working on the API refactor project.",
                lastMemoryUpdate: Date().addingTimeInterval(-86400)
            )
        ]
    }
}

// MARK: - History Memory (Phase 4)

/// Global memory that stores user preferences and recent conversation summaries
public struct HistoryMemory: Codable, Equatable {
    public var summary: String
    public var lastUpdated: Date
    public var conversationCount: Int
    public var recentTopics: [String]  // Last 5 topics for quick context

    public init(
        summary: String = "",
        lastUpdated: Date = Date(),
        conversationCount: Int = 0,
        recentTopics: [String] = []
    ) {
        self.summary = summary
        self.lastUpdated = lastUpdated
        self.conversationCount = conversationCount
        self.recentTopics = recentTopics
    }

    /// Sample history memory for previews
    public static var sample: HistoryMemory {
        HistoryMemory(
            summary: "User prefers formal English for work, casual Polish for family. Often discusses Swift programming and AI topics. Prefers concise responses.",
            lastUpdated: Date().addingTimeInterval(-7200),
            conversationCount: 47,
            recentTopics: ["Swift development", "AI news", "Family planning", "Work emails", "Polish translations"]
        )
    }
}
