;; InsuranceVault - A smart contract for decentralized insurance on Stacks

(define-constant CONTRACT_OWNER tx-sender)
(define-constant STATUS_PENDING u0)
(define-constant STATUS_APPROVED u1)
(define-constant STATUS_REJECTED u2)
(define-constant STATUS_PAID u3)
(define-constant CLAIM_FEE u1000)
(define-constant MIN_PREMIUM u10000) 

;; Data structures
(define-map policies
  { policy-id: uint }
  {
    holder: principal,
    premium-paid: uint,
    coverage-amount: uint,
    start-date: uint,
    end-date: uint,
    is-active: bool
  }
)

(define-map claims
  { claim-id: uint }
  {
    policy-id: uint,
    claimant: principal,
    amount: uint,
    description: (string-utf8 500),
    date-filed: uint,
    status: uint
  }
)

(define-map admins principal bool)

;; Counters for unique IDs
(define-data-var next-policy-id uint u1)
(define-data-var next-claim-id uint u1)

;; Error codes
(define-constant ERR_UNAUTHORIZED u401)
(define-constant ERR_INSUFFICIENT_PAYMENT u402)
(define-constant ERR_INVALID_POLICY u403)
(define-constant ERR_EXPIRED_POLICY u404)
(define-constant ERR_INVALID_CLAIM u405)
(define-constant ERR_INVALID_AMOUNT u406)
(define-constant ERR_CLAIM_ALREADY_PROCESSED u407)

;; Read-only functions

(define-read-only (get-policy (policy-id uint))
  (map-get? policies { policy-id: policy-id })
)

(define-read-only (get-claim (claim-id uint))
  (map-get? claims { claim-id: claim-id })
)

(define-read-only (is-admin (address principal))
  (default-to false (map-get? admins address))
)

(define-read-only (is-policy-active (policy-id uint))
  (let ((policy (get-policy policy-id)))
    (and
      (is-some policy)
      (get is-active (unwrap! policy false))
      (< (get start-date (unwrap! policy false)) block-height)
      (> (get end-date (unwrap! policy false)) block-height)
    )
  )
)

;; Admin functions

(define-public (add-admin (new-admin principal))
  (begin
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (is-admin tx-sender)) (err ERR_UNAUTHORIZED))
    (map-set admins new-admin true)
    (ok true)
  )
)

(define-public (remove-admin (admin principal))
  (begin
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (is-eq tx-sender admin)) (err ERR_UNAUTHORIZED))
    (map-delete admins admin)
    (ok true)
  )
)

;; Insurance policy functions

(define-public (purchase-policy (premium uint) (coverage-amount uint) (duration uint))
  (let
    (
      (policy-id (var-get next-policy-id))
      (start-block block-height)
      (end-block (+ block-height duration))
    )
    ;; Validate inputs
    (asserts! (>= premium MIN_PREMIUM) (err ERR_INSUFFICIENT_PAYMENT))
    (asserts! (> coverage-amount premium) (err ERR_INVALID_AMOUNT))
    
    ;; Process payment
    (try! (stx-transfer? premium tx-sender (as-contract tx-sender)))
    
    ;; Create policy
    (map-set policies
      { policy-id: policy-id }
      {
        holder: tx-sender,
        premium-paid: premium,
        coverage-amount: coverage-amount,
        start-date: start-block,
        end-date: end-block,
        is-active: true
      }
    )
    
    ;; Increment policy ID counter
    (var-set next-policy-id (+ policy-id u1))
    
    (ok policy-id)
  )
)

(define-public (cancel-policy (policy-id uint))
  (let ((policy (unwrap! (get-policy policy-id) (err ERR_INVALID_POLICY))))
    ;; Verify ownership
    (asserts! (is-eq (get holder policy) tx-sender) (err ERR_UNAUTHORIZED))
    
    ;; Update policy status
    (map-set policies
      { policy-id: policy-id }
      (merge policy { is-active: false })
    )
    
    ;; Refund partial premium based on remaining time (simplified calculation)
    (let
      (
        (total-duration (- (get end-date policy) (get start-date policy)))
        (elapsed-duration (- block-height (get start-date policy)))
        (remaining-duration (- (get end-date policy) block-height))
        (refund-amount (if (> remaining-duration u0)
                         (/ (* (get premium-paid policy) remaining-duration) total-duration)
                         u0))
      )
      (if (> refund-amount u0)
        (as-contract (stx-transfer? refund-amount tx-sender (get holder policy)))
        (ok true)
      )
    )
  )
)

;; Claim functions

(define-public (file-claim (policy-id uint) (amount uint) (description (string-utf8 500)))
  (let
    (
      (policy (unwrap! (get-policy policy-id) (err ERR_INVALID_POLICY)))
      (claim-id (var-get next-claim-id))
    )
    ;; Verify policy ownership
    (asserts! (is-eq (get holder policy) tx-sender) (err ERR_UNAUTHORIZED))
    
    ;; Verify policy is active
    (asserts! (is-policy-active policy-id) (err ERR_EXPIRED_POLICY))
    
    ;; Verify claim amount
    (asserts! (<= amount (get coverage-amount policy)) (err ERR_INVALID_AMOUNT))
    
    ;; Collect claim fee
    (try! (stx-transfer? CLAIM_FEE tx-sender (as-contract tx-sender)))
    
    ;; Register claim
    (map-set claims
      { claim-id: claim-id }
      {
        policy-id: policy-id,
        claimant: tx-sender,
        amount: amount,
        description: description,
        date-filed: block-height,
        status: STATUS_PENDING
      }
    )
    
    ;; Increment claim ID counter
    (var-set next-claim-id (+ claim-id u1))
    
    (ok claim-id)
  )
)

(define-public (process-claim (claim-id uint) (approve bool))
  (let ((claim (unwrap! (get-claim claim-id) (err ERR_INVALID_CLAIM))))
    ;; Verify admin status
    (asserts! (is-admin tx-sender) (err ERR_UNAUTHORIZED))
    
    ;; Verify claim is pending
    (asserts! (is-eq (get status claim) STATUS_PENDING) (err ERR_CLAIM_ALREADY_PROCESSED))
    
    ;; Update claim status
    (map-set claims
      { claim-id: claim-id }
      (merge claim { 
        status: (if approve STATUS_APPROVED STATUS_REJECTED)
      })
    )
    
    (ok true)
  )
)

(define-public (pay-claim (claim-id uint))
  (let
    (
      (claim (unwrap! (get-claim claim-id) (err ERR_INVALID_CLAIM)))
      (policy (unwrap! (get-policy (get policy-id claim)) (err ERR_INVALID_POLICY)))
    )
    ;; Verify admin status
    (asserts! (is-admin tx-sender) (err ERR_UNAUTHORIZED))
    
    ;; Verify claim is approved
    (asserts! (is-eq (get status claim) STATUS_APPROVED) (err ERR_UNAUTHORIZED))
    
    ;; Process payment
    (try! (as-contract (stx-transfer? (get amount claim) tx-sender (get claimant claim))))
    
    ;; Update claim status
    (map-set claims
      { claim-id: claim-id }
      (merge claim { status: STATUS_PAID })
    )
    
    ;; If claim amount equals coverage amount, deactivate policy
    (if (is-eq (get amount claim) (get coverage-amount policy))
      (map-set policies
        { policy-id: (get policy-id claim) }
        (merge policy { is-active: false })
      )
      true
    )
    
    (ok true)
  )
)

;; Contract funds management

(define-public (withdraw-funds (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err ERR_UNAUTHORIZED))
    (try! (as-contract (stx-transfer? amount tx-sender CONTRACT_OWNER)))
    (ok true)
  )
)

;; Emergency functions

(define-public (pause-all-policies)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err ERR_UNAUTHORIZED))
    (ok true)
  )
)