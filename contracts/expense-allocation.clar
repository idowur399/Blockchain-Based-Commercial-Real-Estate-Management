;; Expense Allocation Contract
;; Distributes costs among multiple tenants

(define-data-var last-expense-id uint u0)

;; Expense structure
(define-map expenses
  { expense-id: uint }
  {
    property-id: uint,
    property-owner: principal,
    description: (string-utf8 256),
    total-amount: uint,
    date: uint,
    expense-type: (string-utf8 64),
    is-allocated: bool
  }
)

;; Tenant allocation structure
(define-map tenant-allocations
  { expense-id: uint, tenant: principal }
  {
    amount: uint,
    is-paid: bool,
    payment-date: (optional uint)
  }
)

;; Property expenses tracking
(define-map property-expenses
  { property-id: uint }
  { expense-history: (list 100 uint) }
)

;; Tenant expenses tracking
(define-map tenant-expenses
  { tenant: principal }
  { allocated-expenses: (list 100 uint) }
)

;; Create a new expense
(define-public (create-expense
    (property-id uint)
    (description (string-utf8 256))
    (total-amount uint)
    (expense-type (string-utf8 64)))
  (let
    (
      (new-id (+ (var-get last-expense-id) u1))
      (caller tx-sender)
      (current-time (unwrap-panic (get-block-info? time u0)))
      (current-property-expenses (default-to { expense-history: (list) }
                                 (map-get? property-expenses { property-id: property-id })))
    )

    ;; Update last expense ID
    (var-set last-expense-id new-id)

    ;; Add expense to expenses map
    (map-set expenses
      { expense-id: new-id }
      {
        property-id: property-id,
        property-owner: caller,
        description: description,
        total-amount: total-amount,
        date: current-time,
        expense-type: expense-type,
        is-allocated: false
      }
    )

    ;; Update property's expense history
    (map-set property-expenses
      { property-id: property-id }
      { expense-history: (unwrap-panic (as-max-len?
                          (append (get expense-history current-property-expenses) new-id)
                          u100)) }
    )

    (ok new-id)
  )
)

;; Get expense details
(define-read-only (get-expense (expense-id uint))
  (map-get? expenses { expense-id: expense-id })
)

;; Get expenses for a property
(define-read-only (get-property-expenses (property-id uint))
  (map-get? property-expenses { property-id: property-id })
)

;; Get expenses for a tenant
(define-read-only (get-tenant-expenses (tenant principal))
  (map-get? tenant-expenses { tenant: tenant })
)

;; Get tenant allocation for an expense
(define-read-only (get-tenant-allocation (expense-id uint) (tenant principal))
  (map-get? tenant-allocations { expense-id: expense-id, tenant: tenant })
)

;; Allocate expense to a tenant
(define-public (allocate-expense-to-tenant
    (expense-id uint)
    (tenant principal)
    (amount uint))
  (let
    (
      (expense (unwrap! (map-get? expenses { expense-id: expense-id }) (err u1)))
      (caller tx-sender)
      (property-owner (get property-owner expense))
      (is-allocated (get is-allocated expense))
      (current-tenant-expenses (default-to { allocated-expenses: (list) }
                               (map-get? tenant-expenses { tenant: tenant })))
    )

    ;; Check if caller is the property owner
    (asserts! (is-eq caller property-owner) (err u2))

    ;; Check if expense is not already fully allocated
    (asserts! (not is-allocated) (err u3))

    ;; Add allocation to tenant-allocations map
    (map-set tenant-allocations
      { expense-id: expense-id, tenant: tenant }
      {
        amount: amount,
        is-paid: false,
        payment-date: none
      }
    )

    ;; Update tenant's expense list
    (map-set tenant-expenses
      { tenant: tenant }
      { allocated-expenses: (unwrap-panic (as-max-len?
                             (append (get allocated-expenses current-tenant-expenses) expense-id)
                             u100)) }
    )

    (ok true)
  )
)

;; Mark expense as fully allocated
(define-public (mark-expense-allocated (expense-id uint))
  (let
    (
      (expense (unwrap! (map-get? expenses { expense-id: expense-id }) (err u1)))
      (caller tx-sender)
      (property-owner (get property-owner expense))
    )

    ;; Check if caller is the property owner
    (asserts! (is-eq caller property-owner) (err u2))

    ;; Update expense allocation status
    (map-set expenses
      { expense-id: expense-id }
      (merge expense { is-allocated: true })
    )

    (ok true)
  )
)

;; Mark tenant allocation as paid
(define-public (mark-allocation-paid (expense-id uint) (tenant principal))
  (let
    (
      (allocation (unwrap! (map-get? tenant-allocations { expense-id: expense-id, tenant: tenant }) (err u1)))
      (expense (unwrap! (map-get? expenses { expense-id: expense-id }) (err u2)))
      (caller tx-sender)
      (property-owner (get property-owner expense))
      (current-time (unwrap-panic (get-block-info? time u0)))
    )

    ;; Check if caller is the property owner
    (asserts! (is-eq caller property-owner) (err u3))

    ;; Update allocation payment status
    (map-set tenant-allocations
      { expense-id: expense-id, tenant: tenant }
      (merge allocation {
        is-paid: true,
        payment-date: (some current-time)
      })
    )

    (ok true)
  )
)

;; Get total unpaid allocations for a tenant - simplified
(define-read-only (get-tenant-unpaid-total (tenant principal))
  u0 ;; Simplified to just return 0 for now
)

