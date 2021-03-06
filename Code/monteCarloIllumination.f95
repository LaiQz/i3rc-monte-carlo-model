! Copyight 2003-2009, Regents of the University of Colorado. All right reserved
! Use and duplication is permitted under the terms of the 
!   GNU public license, V2 : http://www.gnu.org/licenses/old-licenses/gpl-2.0.html
! NASA has special rights noted in License.txt

! $Revision$, $Date$
! $URL$
module monteCarloIllumination
  ! Provides an object representing a series of photons. The object specifies the 
  !   initial x, y position and direction. 
  ! In principle any arbitrary illumination condition can be specified. 
  ! Initial x, y positions are between 0 and 1, and must be scaled by the Monte Carlo
  !   integrator. 
  ! On input, azimuth is in degrees and zenith angle is specified as the cosine. 
  ! On output, azimuth is in radians (0, 2 pi) and solar mu is negative (down-going). 
  
  use ErrorMessages, only: ErrorMessage,   &
                           stateIsFailure, &
                           setStateToFailure, setStateToSuccess
  use RandomNumbers, only: randomNumberSequence, &
                           getRandomReal
  implicit none
  private

  !------------------------------------------------------------------------------------------
  ! Constants
  !------------------------------------------------------------------------------------------
  logical, parameter :: useFiniteSolarWidth = .false. 
  real,    parameter :: halfAngleDiamaterOfSun = 0.25 ! degrees
  
  !------------------------------------------------------------------------------------------
  ! Type (object) definitions
  !------------------------------------------------------------------------------------------
  type photonStream
    integer                     :: currentPhoton = 0
    real, dimension(:), pointer :: xPosition => null()
    real, dimension(:), pointer :: yPosition => null()
    real, dimension(:), pointer :: zPosition => null()
    real, dimension(:), pointer :: initialMu  => null()
    real, dimension(:), pointer :: initialPhi => null()
  end type photonStream
  
  !------------------------------------------------------------------------------------------
  ! Overloading
  !------------------------------------------------------------------------------------------
  interface new_PhotonStream
    module procedure newPhotonStream_Directional, newPhotonStream_RandomAzimuth, &
                     newPhotonStream_Flux, newPhotonStream_Spotlight,            &
                     newPhotonStream_Internal_Flux, newPhotonStream_Internal_Intensity
  end interface new_PhotonStream
  !------------------------------------------------------------------------------------------
  ! What is visible? 
  !------------------------------------------------------------------------------------------
  public :: photonStream 
  public :: new_PhotonStream, finalize_PhotonStream, morePhotonsExist, getNextPhoton
contains
  !------------------------------------------------------------------------------------------
  ! Code
  !------------------------------------------------------------------------------------------
  ! Initialization: Routines to create streams of incoming photons
  !------------------------------------------------------------------------------------------
  function newPhotonStream_Directional(solarMu, solarAzimuth, &
                                       numberOfPhotons, randomNumbers, status) result(photons)
    ! Create a set of incoming photons with specified initial zenith angle cosine and  
    !   azimuth. 
    real,                       intent(in   ) :: solarMu, solarAzimuth
    integer                                   :: numberOfPhotons
    type(randomNumberSequence), intent(inout) :: randomNumbers
    type(ErrorMessage),         intent(inout) :: status
    type(photonStream)                        :: photons
    
    ! -------------------------------------------------
    ! Local variables
    integer :: i
    
    ! -------------------------------------------------
   ! Checks: are input parameters specified correctly? 
    if(numberOfPhotons <= 0) &
      call setStateToFailure(status, "setIllumination: must ask for non-negative number of photons.")
    if(solarAzimuth < 0. .or. solarAzimuth > 360.) &
      call setStateToFailure(status, "setIllumination: solarAzimuth out of bounds")
    if(abs(solarMu) > 1. .or. abs(solarMu) <= tiny(solarMu)) &
      call setStateToFailure(status, "setIllumination: solarMu out of bounds")
    
    ! -------------------------------------------------
    if(.not. stateIsFailure(status)) then
      allocate(photons%xPosition(numberOfPhotons),   photons%yPosition(numberOfPhotons), &
               photons%zPosition(numberOfPhotons),                                       &
               photons%initialMu(numberOfPhotons), photons%initialPhi(numberOfPhotons))
                        
      do i = 1, numberOfPhotons
        ! Random initial positions 
        photons%xPosition(i) = getRandomReal(randomNumbers)
        photons%yPosition(i) = getRandomReal(randomNumbers)
      end do
      photons%zPosition(1:numberOfPhotons) = 1. - spacing(1.) 
      ! Specified inital directions
      photons%initialMu( 1:numberOfPhotons) = -abs(solarMu)
      photons%initialPhi(1:numberOfPhotons) = solarAzimuth * acos(-1.) / 180. 
      photons%currentPhoton = 1
      
      call setStateToSuccess(status)
   end if   
  end function newPhotonStream_Directional
  ! ------------------------------------------------------
  function newPhotonStream_RandomAzimuth(solarMu, numberOfPhotons, randomNumbers, status) &
           result(photons)
    ! Create a set of incoming photons with specified initial zenith angle cosine but
    !  random initial azimuth. 
    real,                       intent(in   ) :: solarMu
    integer                                   :: numberOfPhotons
    type(randomNumberSequence), intent(inout) :: randomNumbers
    type(ErrorMessage),         intent(inout) :: status
    type(photonStream)                        :: photons

    ! -------------------------------------------------
    ! Local variables
    integer :: i
    
    ! -------------------------------------------------
    ! Checks: are input parameters specified correctly? 
    if(numberOfPhotons <= 0) &
      call setStateToFailure(status, "setIllumination: must ask for non-negative number of photons.")
    if(abs(solarMu) > 1. .or. abs(solarMu) <= tiny(solarMu)) &
      call setStateToFailure(status, "setIllumination: solarMu out of bounds")
    
    ! -------------------------------------------------
    if(.not. stateIsFailure(status)) then
      allocate(photons%xPosition(numberOfPhotons),   photons%yPosition(numberOfPhotons), &
               photons%zPosition(numberOfPhotons),                                       &
               photons%initialMu(numberOfPhotons), photons%initialPhi(numberOfPhotons))
      do i = 1, numberOfPhotons
        ! Random initial positions 
        photons%xPosition( i) = getRandomReal(randomNumbers)
        photons%yPosition( i) = getRandomReal(randomNumbers)
        ! Random initial azimuth
        photons%initialPhi(i) = getRandomReal(randomNumbers) * 2. * acos(-1.) 
      end do
      photons%zPosition(1:numberOfPhotons) = 1. - spacing(1.) 
      ! but specified inital mu
      photons%initialMu(1:numberOfPhotons) = -abs(solarMu)
      photons%currentPhoton = 1
      
      call setStateToSuccess(status)
    end if   
 end function newPhotonStream_RandomAzimuth
 ! ------------------------------------------------------
 function newPhotonStream_Flux(numberOfPhotons, randomNumbers, status) result(photons)
    ! Create a set of incoming photons with random initial azimuth and initial
    !  mus constructed so the solar flux on the horizontal is equally weighted
    !  in mu (daytime average is 1/2 solar constant; this is "global" average weighting)
    integer                                   :: numberOfPhotons
    type(randomNumberSequence), intent(inout) :: randomNumbers
    type(ErrorMessage),         intent(inout) :: status
    type(photonStream)                        :: photons
    
    ! -------------------------------------------------
    ! Local variables
    integer :: i
    
    ! -------------------------------------------------
    ! Checks
    if(numberOfPhotons <= 0) &
      call setStateToFailure(status, "setIllumination: must ask for non-negative number of photons.")
     
    ! -------------------------------------------------
    if(.not. stateIsFailure(status)) then
      allocate(photons%xPosition(numberOfPhotons),   photons%yPosition(numberOfPhotons), &
               photons%zPosition(numberOfPhotons),                                       &
               photons%initialMu(numberOfPhotons),  photons%initialPhi(numberOfPhotons))
               
      do i = 1, numberOfPhotons
        ! Random initial positions
        photons%xPosition( i) = getRandomReal(randomNumbers)
        photons%yPosition( i) = getRandomReal(randomNumbers)
        ! Random initial directions
        photons%initialMu( i) = -sqrt(getRandomReal(randomNumbers)) 
        photons%initialPhi(i) = getRandomReal(randomNumbers) * 2. * acos(-1.)
      end do
      photons%zPosition(1:numberOfPhotons) = 1. - spacing(1.) 
      
      photons%currentPhoton = 1
      call setStateToSuccess(status)  
    end if     
  end function newPhotonStream_Flux
  !------------------------------------------------------------------------------------------
  function newPhotonStream_Spotlight(solarMu, solarAzimuth, solarX, solarY, &
                                     numberOfPhotons, randomNumbers, status) result(photons)
    ! Create a set of incoming photons with specified initial zenith angle cosine and  
    !   azimuth. 
    real,                       intent(in   ) :: solarMu, solarAzimuth, solarX, solarY
    integer                                   :: numberOfPhotons
    type(randomNumberSequence), optional, &
                                intent(inout) :: randomNumbers
    type(ErrorMessage),         intent(inout) :: status
    type(photonStream)                        :: photons
        
    ! -------------------------------------------------
    ! Checks: are input parameters specified correctly? 
    if(numberOfPhotons <= 0) &
      call setStateToFailure(status, "setIllumination: must ask for non-negative number of photons.")
    if(solarAzimuth < 0. .or. solarAzimuth > 360.) &
      call setStateToFailure(status, "setIllumination: solarAzimuth out of bounds")
    if(abs(solarMu) > 1. .or. abs(solarMu) <= tiny(solarMu)) &
      call setStateToFailure(status, "setIllumination: solarMu out of bounds")
    if(solarX > 1. .or. solarX <= 0. .or. &
       solarY > 1. .or. solarY <= 0. )    &
      call setStateToFailure(status, "setIllumination: x and y positions must be between 0 and 1")
    
    ! -------------------------------------------------
    if(.not. stateIsFailure(status)) then
      allocate(photons%xPosition(numberOfPhotons),   photons%yPosition(numberOfPhotons), &
               photons%zPosition(numberOfPhotons),                                       &
               photons%initialMu(numberOfPhotons), photons%initialPhi(numberOfPhotons))
                        
      ! Specified inital directions and position
      photons%initialMu( 1:numberOfPhotons) = -abs(solarMu)
      photons%initialPhi(1:numberOfPhotons) = solarAzimuth * acos(-1.) / 180. 
      photons%xPosition( 1:numberOfPhotons) = solarX
      photons%yPosition( 1:numberOfPhotons) = solarY
      photons%zPosition( 1:numberOfPhotons) = 1. - spacing(1.) 
      photons%currentPhoton = 1
      
      call setStateToSuccess(status)
   end if   
  end function newPhotonStream_Spotlight
  !------------------------------------------------------------------------------------------
  function newPhotonStream_Internal_Flux(detectorX, detectorY, detectorZ, detectorPointsUp, &
                                         deltaX, deltaY,                                    &
                                         numberOfPhotons, randomNumbers, status) result(photons)
                                         
    real,                       intent(in)    :: detectorX, detectorY, detectorZ 
                                                 ! Detector center
    logical,                    intent(in)    :: detectorPointsUp
    real,             optional, intent(in)    :: deltaX, deltaY  
                                                 ! Detector full width 
    integer                                   :: numberOfPhotons
    type(randomNumberSequence), optional, &
                                intent(inout) :: randomNumbers
    type(ErrorMessage),         intent(inout) :: status
    type(photonStream)                        :: photons
    
    ! Backwards Monte Carlo - create an internal source of photons distributed over the hemisphere
    
    ! -------------------------------------------------
    integer :: i, numberToReplace
    integer, dimension(numberOfPhotons) :: photonsToReplace
    
    ! -------------------------------------------------
    ! Checks: are input parameters specified correctly? 
    if(numberOfPhotons <= 0) &
      call setStateToFailure(status, "setIllumination: must ask for non-negative number of photons.")
    if(detectorX > 1. .or. detectorX <= 0. .or. &
       detectorY > 1. .or. detectorY <= 0. .or. &
       detectorZ > 1. .or. detectorZ <= 0. )    &
      call setStateToFailure(status, "setIllumination: x, y, z positions must be between 0 and 1")
    if(present(deltaX)) then 
      if(detectorX + deltaX/2. > 1. .or. detectorX - deltaX/2 <= 0.) &
        call setStateToFailure(status, "setIllumination: max, min positions must be between 0 and 1")
    end if 
    if(present(deltaY)) then 
      if(detectorY + deltaY/2. > 1. .or. detectorY - deltaY/2 <= 0.) &
        call setStateToFailure(status, "setIllumination: max, min positions must be between 0 and 1")
    end if 
    if(      detectorPointsUp .and. abs(detectorZ - 1.) < 2. * spacing(1.)) &
      call setStateToWarning(status, "setIllumination: Detector is at top of domain pointed up")
    if(.not. detectorPointsUp .and. detectorZ           < 2. * tiny(0.)   ) &
      call setStateToWarning(status, "setIllumination: Detector is at bottom of domain pointed down")

    ! -------------------------------------------------
    if(.not. stateIsFailure(status)) then
      allocate(photons%xPosition(numberOfPhotons), photons%yPosition(numberOfPhotons), &
               photons%zPosition(numberOfPhotons),                                     &
               photons%initialMu(numberOfPhotons), photons%initialPhi(numberOfPhotons))
                        
      photons%xPosition(1:numberOfPhotons) = detectorX
      photons%yPosition(1:numberOfPhotons) = detectorY
      photons%zPosition(1:numberOfPhotons) = detectorZ
      !
      ! People might specify the boundaries; it's easier to buy ourselves a smidgen of breathing room
      !
      if(detectorPointsUp) then 
        photons%zPosition(1:numberOfPhotons) = max(photons%zPosition(1:numberOfPhotons), 2. * tiny(0.))
      else
        photons%zPosition(1:numberOfPhotons) = min(photons%zPosition(1:numberOfPhotons), 1. - spacing(1.))
      end if 
      do i = 1, numberOfPhotons
        ! Random initial directions
        photons%initialMu (i) = sqrt(getRandomReal(randomNumbers)) 
        photons%initialPhi(i) = getRandomReal(randomNumbers) * 2. * acos(-1.)
      end do 
      if(.not. detectorPointsUp) photons%initialMu(1:numberOfPhotons) = -photons%initialMu(1:numberOfPhotons)
      
      !
      ! Choose new directions for any photons with mu == 0. These should be very rare, but it's possible
      !   that the layer in which they're introduced has no extinction, and hence no scattering, 
      !   anywhere, in which case they'll travel endlessly. 
      !
      numberToReplace = count(abs(photons%initialMu) <= 2. * tiny(0.))
      do while (numberToReplace > 0) 
        photonsToReplace(1:numberToReplace) = pack((/ (i, i = 1, numberOfPhotons ) /), & 
                                                   mask = abs(photons%initialMu) < 2. * tiny(0.)) 
        do i = 1, numberToReplace
          photons%initialMu(photonsToReplace(i)) = sqrt(getRandomReal(randomNumbers)) 
        end do 
        numberToReplace = count(abs(photons%initialMu) < 2. * tiny(0.))
      end do 

      !
      ! Finite width detector 
      !
      if(present(deltaX)) then 
        do i = 1, numberOfPhotons
          photons%xPosition(i) = photons%xPosition(i) + deltaX * (1. - 0.5 * getRandomReal(randomNumbers))
        end do 
      end if

      if(present(deltaY)) then 
        do i = 1, numberOfPhotons
          photons%yPosition(i) = photons%yPosition(i) + deltaY * (1. - 0.5 * getRandomReal(randomNumbers))
        end do 
      end if
      
      photons%currentPhoton = 1
      call setStateToSuccess(status)
   end if   
  end function newPhotonStream_Internal_Flux
  !------------------------------------------------------------------------------------------
  function newPhotonStream_Internal_Intensity(detectorX, detectorY, detectorZ, & 
                                              detectorMu, detectorPhi,         &
                                              deltaX,     deltaY,    deltaTheta, &
                                              numberOfPhotons, randomNumbers, status) result(photons)
                                         
    real,               intent(in)    :: detectorX, detectorY, detectorZ 
                                         ! Detector center
    real,               intent(in)    :: detectorMu, detectorPhi    ! phi in degrees
    real,     optional, intent(in)    :: deltaX, deltaY, deltaTheta ! deltaTheta in degrees 
                                                 ! Detector full width 
    integer                           :: numberOfPhotons
    type(randomNumberSequence), & 
              optional, intent(inout) :: randomNumbers
    type(ErrorMessage), intent(inout) :: status
    type(photonStream)                :: photons
    
    ! Backwards Monte Carlo - create an internal source of photons in a single direction
    
    ! -------------------------------------------------
    integer :: i, numberToReplace
    integer, dimension(numberOfPhotons) :: photonsToReplace    
    ! -------------------------------------------------
    
    ! Checks: are input parameters specified correctly? 
    if(numberOfPhotons <= 0) &
      call setStateToFailure(status, "setIllumination: must ask for non-negative number of photons.")
    if(detectorX > 1. .or. detectorX <= 0. .or. &
       detectorY > 1. .or. detectorY <= 0. .or. &
       detectorZ > 1. .or. detectorZ <= 0. )    &
      call setStateToFailure(status, "setIllumination: x, y, z positions must be between 0 and 1")
    if(present(deltaX)) then 
      if(detectorX + deltaX/2. > 1. .or. detectorX - deltaX/2 <= 0.) &
        call setStateToFailure(status, "setIllumination: max, min positions must be between 0 and 1")
    end if 
    if(present(deltaY)) then 
      if(detectorY + deltaY/2. > 1. .or. detectorY - deltaY/2 <= 0.) &
        call setStateToFailure(status, "setIllumination: max, min positions must be between 0 and 1")
    end if 
    
    if(detectorPhi < 0. .or. detectorPhi > 360.) &
      call setStateToFailure(status, "setIllumination: detectorPhi out of bounds")
    if(abs(detectorMu) > 1. .or. abs(detectorMu) <= tiny(detectorMu)) &
      call setStateToFailure(status, "setIllumination: detectorMu out of bounds")
      
    if(detectorMu > 0. .and. abs(detectorZ - 1.) < 2. * spacing(1.)) &
      call setStateToWarning(status, "setIllumination: Detector is at top of domain pointed up")
    if(detectorMu < 0. .and. detectorZ           < 2. * tiny(0.)   ) &
      call setStateToWarning(status, "setIllumination: Detector is at bottom of domain pointed down")

    if(present(deltaTheta)) & 
      call setStateToWarning(status, "setIllumination: Finite detector angular width not yet implemented")
      
    ! -------------------------------------------------
    
    if(.not. stateIsFailure(status)) then
      allocate(photons%xPosition(numberOfPhotons), photons%yPosition(numberOfPhotons), &
               photons%zPosition(numberOfPhotons),                                     &
               photons%initialMu(numberOfPhotons), photons%initialPhi(numberOfPhotons))
                        
      photons%xPosition (1:numberOfPhotons) = detectorX
      photons%yPosition (1:numberOfPhotons) = detectorY
      photons%zPosition (1:numberOfPhotons) = detectorZ
      photons%initialMu (1:numberOfPhotons) = detectorMu
      photons%initialPhi(1:numberOfPhotons) = detectorPhi
      !
      ! People might specify the boundaries; it's easier to buy ourselves a smidgen of breathing room
      !
      if(detectorMu > tiny(detectorMu)) then 
        photons%zPosition(1:numberOfPhotons) = max(photons%zPosition(1:numberOfPhotons), 2. * tiny(0.))
      else
        photons%zPosition(1:numberOfPhotons) = min(photons%zPosition(1:numberOfPhotons), 1. - spacing(1.))
      end if 

      !
      ! Finite extent detector 
      !
      if(present(deltaX)) then 
        do i = 1, numberOfPhotons
          photons%xPosition(i) = photons%xPosition(i) + deltaX * (1. - 0.5 * getRandomReal(randomNumbers))
        end do 
      end if

      if(present(deltaY)) then 
        do i = 1, numberOfPhotons
          photons%yPosition(i) = photons%yPosition(i) + deltaY * (1. - 0.5 * getRandomReal(randomNumbers))
        end do 
      end if
      
      !
      ! Finite angular resolution - not yet implemented 
      !

      photons%currentPhoton = 1
      call setStateToSuccess(status)
   end if   
  end function newPhotonStream_Internal_Intensity
  !------------------------------------------------------------------------------------------
  ! Are there more photons? Get the next photon in the sequence
  !------------------------------------------------------------------------------------------
  function morePhotonsExist(photons)
    type(photonStream), intent(inout) :: photons
    logical                           :: morePhotonsExist
    
    morePhotonsExist = photons%currentPhoton > 0 .and. &
                       photons%currentPhoton <= size(photons%xPosition)
  end function morePhotonsExist
  !------------------------------------------------------------------------------------------
  subroutine getNextPhoton(photons, xPosition, yPosition, zPosition, solarMu, solarAzimuth, status)
    type(photonStream), intent(inout) :: photons
    real,                 intent(  out) :: xPosition, yPosition, zPosition, solarMu, solarAzimuth
    type(ErrorMessage),   intent(inout) :: status
    
    ! Checks 
    ! Are there more photons?
    if(photons%currentPhoton < 1) &
      call setStateToFailure(status, "getNextPhoton: photons have not been initialized.")  
    if(.not. stateIsFailure(status)) then
      if(photons%currentPhoton > size(photons%xPosition)) &
        call setStateToFailure(status, "getNextPhoton: Ran out of photons")
    end if
      
    if(.not. stateIsFailure(status)) then
      xPosition    = photons%xPosition(photons%currentPhoton) 
      yPosition    = photons%yPosition(photons%currentPhoton)
      zPosition    = photons%zPosition(photons%currentPhoton)
      solarMu      = photons%initialMu(photons%currentPhoton)
      solarAzimuth = photons%initialPhi(photons%currentPhoton)
      photons%currentPhoton = photons%currentPhoton + 1
    end if
     
  end subroutine getNextPhoton
  !------------------------------------------------------------------------------------------
  ! Finalization
  !------------------------------------------------------------------------------------------
  subroutine finalize_PhotonStream(photons)
    type(photonStream), intent(inout) :: photons
    ! Free memory and nullify pointers. This leaves the variable in 
    !   a pristine state
    if(associated(photons%xPosition))  deallocate(photons%xPosition)
    if(associated(photons%yPosition))  deallocate(photons%yPosition)
    if(associated(photons%zPosition))  deallocate(photons%zPosition)
    if(associated(photons%initialMu))  deallocate(photons%initialMu)
    if(associated(photons%initialPhi)) deallocate(photons%initialPhi)
    
    photons%currentPhoton = 0
  end subroutine finalize_PhotonStream
end module monteCarloIllumination