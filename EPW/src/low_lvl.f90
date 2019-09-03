  !
  ! Copyright (C) 2016-2019 Samuel Ponce', Roxana Margine, Feliciano Giustino
  ! 
  ! This file is distributed under the terms of the GNU General Public         
  ! License. See the file `LICENSE' in the root directory of the               
  ! present distribution, or http://www.gnu.org/copyleft.gpl.txt .
  !
  !----------------------------------------------------------------------
  MODULE low_lvl
  !----------------------------------------------------------------------
  !! 
  !! This module contains low level routines that are used throughout EPW. 
  !! 
  IMPLICIT NONE
  ! 
  CONTAINS
    ! 
    !-----------------------------------------------------------------------
    LOGICAL function hslt(a, b)
    !-----------------------------------------------------------------------
    !! 
    !! compare two real number and return the result
    !!  
    REAL(KIND = DP), INTENT(in) :: a
    !! Input number a
    REAL(KIND = DP), INTENT(in) :: b
    !! Input number b
    IF (ABS(a-b) < eps) THEN
      hslt = .FALSE.
    ELSE
      hslt = (a < b )
    ENDIF
    !-----------------------------------------------------------------------
    END FUNCTION hslt
    !-----------------------------------------------------------------------
    ! 
    !-----------------------------------------------------------------------
    SUBROUTINE init_random_seed()
    !-----------------------------------------------------------------------
    !! 
    !! Create seeds for random number generation
    !!
    !-----------------------------------------------------------------------
    !
    INTEGER :: i
    !! Division by number running from 1 to n
    INTEGER :: n
    !! Random number
    INTEGER :: clock
    !! Clock count
    INTEGER, ALLOCATABLE :: seed(:)
    !! Seeds
    !     
    CALL RANDOM_SEED(SIZE = n)
    ALLOCATE(seed(n))
    !      
    CALL SYSTEM_CLOCK(COUNT = clock)
    !        
    seed = clock + 37 * (/(i - 1, i = 1, n)/)
    CALL RANDOM_SEED(PUT = seed)
    !        
    DEALLOCATE(seed)
    !
    !-----------------------------------------------------------------------
    END SUBROUTINE init_random_seed
    !-----------------------------------------------------------------------
    ! 
    !-----------------------------------------------------------------------
    SUBROUTINE fermiwindow 
    !-----------------------------------------------------------------------
    !
    ! Find the band indices of the first
    ! and last state falling within the window e_fermi+-efermithickness
    ! 
    !-----------------------------------------------------------------------
    !
    USE kinds,         ONLY : DP
    USE io_global,     ONLY : stdout
    USE elph2,         ONLY : etf, ibndmin, ibndmax, nkqf
    USE epwcom,        ONLY : fsthick, nbndsub
    USE pwcom,         ONLY : ef
    USE mp,            ONLY : mp_max, mp_min
    USE mp_global,     ONLY : inter_pool_comm
    !
    IMPLICIT NONE
    !
    INTEGER :: ik
    !! Counter on k-points in the pool
    INTEGER :: ibnd
    !! Counter on bands
    REAL(KIND = DP) :: ebnd
    !! Eigenvalue at etf(ibnd, ik)
    REAL(KIND = DP) :: ebndmin
    !! Minimum eigenvalue
    REAL(KIND = DP) :: ebndmax
    !! Maximum eigenvalue
    REAL(KIND = DP) :: tmp
    !
    !
    ibndmin = 100000
    ibndmax = 0
    ebndmin =  1.d8
    ebndmax = -1.d8
    !
    DO ik = 1, nkqf
      DO ibnd = 1, nbndsub
        ebnd = etf(ibnd, ik)
        !
        IF (ABS(ebnd - ef) < fsthick) THEN
          ibndmin = MIN(ibnd, ibndmin)
          ibndmax = MAX(ibnd, ibndmax)
          ebndmin = MIN(ebnd, ebndmin)
          ebndmax = MAX(ebnd, ebndmax)
        ENDIF
        !
      ENDDO
    ENDDO
    !
    tmp = DBLE(ibndmin)
    CALL mp_min(tmp, inter_pool_comm)
    ibndmin = NINT(tmp)
    CALL mp_min(ebndmin, inter_pool_comm)
    !
    tmp = DBLE(ibndmax)
    CALL mp_max(tmp, inter_pool_comm)
    ibndmax = NINT(tmp)
    CALL mp_max(ebndmax, inter_pool_comm)
    !
    WRITE(stdout,'(/14x,a,i5,2x,a,f9.3)') 'ibndmin = ', ibndmin, 'ebndmin = ', ebndmin
    WRITE(stdout,'(14x,a,i5,2x,a,f9.3/)') 'ibndmax = ', ibndmax, 'ebndmax = ', ebndmax
    !
    !----------------------------------------------------------------------
    END SUBROUTINE fermiwindow
    !---------------------------------------------------------------------
    ! 
    !---------------------------------------------------------------------
    SUBROUTINE hpsort_eps_epw(n, ra, ind, eps)
    !---------------------------------------------------------------------
    !! This routine is adapted from flib/hpsort_eps 
    !! Sort an array ra(1:n) into ascending order using heapsort algorithm,
    !! and considering two elements being equal if their values differ
    !! for less than "eps".
    !! n is input, ra is replaced on output by its sorted rearrangement.
    !! create an index table (ind) by making an exchange in the index array
    !! whenever an exchange is made on the sorted data array (ra).
    !! in case of equal values in the data array (ra) the values in the
    !! index array (ind) are used to order the entries.
    !! if on input ind(1)  = 0 then indices are initialized in the routine,
    !! if on input ind(1) != 0 then indices are assumed to have been
    !!                initialized before entering the routine and these
    !!                indices are carried around during the sorting process
    !!
    !! no work space needed !
    !! free us from machine-dependent sorting-routines !
    !!
    !! adapted from Numerical Recipes pg. 329 (new edition)
    !
    use kinds, ONLY : DP
    ! 
    IMPLICIT NONE  
    ! 
    INTEGER, INTENT(in) :: n
    !! Size of the array  
    INTEGER, INTENT(in) :: ind(n)
    !! Array
    REAL(KIND = DP), INTENT(inout) :: ra(n)
    !! Sorted array
    REAL(KIND = DP), INTENT(in) :: eps
    !! Tolerence
    ! 
    ! Local variables
    INTEGER :: i
    !! 
    INTEGER :: ir
    !! 
    INTEGER :: j
    !! 
    INTEGER :: l
    !! 
    INTEGER :: iind  
    !! 
    REAL(KIND = DP) :: rra  
    !! Input array 
    ! 
    ! initialize index array
    IF (ind(1)  == 0) THEN
      DO i = 1, n  
        ind (i) = i  
      ENDDO
    ENDIF
    ! nothing to order
    IF (n < 2) RETURN
    ! initialize indices for hiring and retirement-promotion phase
    l = n / 2 + 1  
    ! 
    ir = n  
    ! 
    SORTING: DO
      ! still in hiring phase
      IF (l > 1) THEN  
        l = l - 1  
        rra  = ra(l)  
        iind = ind(l)  
        ! in retirement-promotion phase.
      ELSE  
        ! clear a space at the end of the array
        rra  = ra(ir)  
        iind = ind(ir)  
        ! retire the top of the heap into it
        ra(ir) = ra(1)  
        !
        ind(ir) = ind(1)  
        ! decrease the size of the corporation
        ir = ir - 1  
        ! done with the last promotion
        IF (ir == 1) THEN
          ! the least competent worker at all !
          ra(1) = rra  
          ind(1) = iind  
          EXIT sorting  
        ENDIF
      ENDIF
      ! Wheter in hiring or promotion phase, we
      i = l  
      ! Set up to place rra in its proper level
      j = l + l  
      !
      DO WHILE(j <= ir)  
        IF (j < ir) THEN  
          ! compare to better underling
          IF (hslt(ra(j), ra(j + 1))) THEN 
            j = j + 1  
          ENDIF
        ENDIF
        ! demote rra
        IF (hslt(rra, ra(j))) THEN  
          ra(i) = ra(j)  
          ind(i) = ind(j)  
          i = j  
          j = j + j  
        ELSE
          ! set j to terminate do-while loop
          j = ir + 1  
        ENDIF
      ENDDO
      ra(i) = rra  
      ind(i) = iind  
      ! 
    ENDDO sorting    
    !
    !----------------------------------------------------------------------
    END SUBROUTINE hpsort_eps_epw
    !----------------------------------------------------------------------
    ! 
    !----------------------------------------------------------------
    SUBROUTINE set_ndnmbr(pool, proc, procp, npool, ndlab)
    !----------------------------------------------------------------
    !!
    !!  create ndlab label from pool and proc numbers
    !!
    !!  The rule for deciding the node number is based on 
    !!  the restriction set in startup.f90 that every pool 
    !!  has the same number of procs.
    !!
    !----------------------------------------------------------------
    IMPLICIT NONE
    ! 
    CHARACTER(LEN = 3), INTENT(out) :: ndlab 
    !! Label
    INTEGER, INTENT(in) :: pool
    !! Pool = 1,..., npool
    INTEGER, INTENT(in) :: proc
    !! Processor = 0,..., nproc_pool-1
    INTEGER, INTENT(in) :: procp
    !! 
    INTEGER, INTENT(in) :: npool
    !! 
    ! Local variables
    INTEGER :: node
    !! Number of nodes 
    INTEGER :: nprocs
    !! 
    !
    nprocs = npool * procp
    !
    node = (pool - 1) * procp + proc + 1
    !
    ndlab = '   '
    IF (nprocs < 10) THEN
      WRITE(ndlab(1:1), '(i1)') node
    ELSEIF (nprocs < 100 ) then
      IF (node < 10) THEN
        WRITE(ndlab(1:1), '(i1)') node
      ELSE
        WRITE(ndlab(1:2), '(i2)') node
      ENDIF
    ELSEIF (nprocs < 100) THEN
      IF (node < 10) THEN
        WRITE(ndlab(1:1), '(i1)') node
      ELSEIF (node < 100) THEN
        WRITE(ndlab(1:2), '(i2)') node
      ELSE
        WRITE(ndlab(1:3), '(i3)') node
      ENDIF
    ELSE
      IF (node < 10) THEN
        WRITE(ndlab(1:1), '(i1)') node
      ELSEIF (node < 100) THEN
        WRITE(ndlab(1:2), '(i2)') node
      ELSEIF (node < 1000) THEN
        WRITE(ndlab(1:3), '(i3)') node
      ELSE
        WRITE(ndlab, '(i4)') node
      ENDIF
    ENDIF
    !
    !----------------------------------------------------------------
    END SUBROUTINE set_ndnmbr
    !----------------------------------------------------------------
    ! 
  !----------------------------------------------------------------------
  END MODULE low_lvl
  !----------------------------------------------------------------------

