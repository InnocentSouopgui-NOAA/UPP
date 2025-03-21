!> @file
!> @brief This routine posts surface-based fields.
!>     
!> ### Program history log:
!> Date | Programmer | Comments
!> -----|------------|---------
!> 1992-12-21 | RUSS TREADON    | Initial
!> 1994-08-04 | MICHAEL BALDWIN | ADDED OUTPUT OF SFC FLUXES OF SENS AND LATENT HEAT AND THETA AT Z0
!> 1994-11-04 | MICHAEL BALDWIN | ADDED INSTANTANEOUS PRECIP TYPE
!> 1996-03-19 | MICHAEL BALDWIN | CHANGE SOIL PARAMETERS
!> 1996-09-25 | MICHAEL BALDWIN | ADDED SNOW RATIO FROM EXPLICIT SCHEME
!> 1996-10-17 | MICHAEL BALDWIN | CHANGED SFCEVP,POTEVP TO ACCUM. TOOK OUT -PTRACE FOR ACSNOW,SSROFF,BGROFF.
!> 1997-04-23 | MICHAEL BALDWIN | TOOK OUT -PTRACE FOR ALL PRECIP FIELDS
!> 1998-06-12 | T BLACK         | CONVERSION FROM 1-D TO 2-D
!> 1998-07-17 | MIKE BALDWIN | REMOVED LABL84
!> 1998-08-18 | MIKE BALDWIN | COMPUTE RH OVER ICE
!> 1998-12-22 | MIKE BALDWIN | BACK OUT RH OVER ICE
!> 2000-01-04 | JIM TUCCILLO | MPI VERSION
!> 2001-10-22 | H CHUANG     | MODIFIED TO PROCESS HYBRID MODEL OUTPUT
!> 2002-06-11 | MIKE BALDWIN | WRF VERSION ASSUMING ALL ACCUM VARS HAVE BUCKETS THAT FILL FROM T=00H ON
!> 2002-08-28 | H CHUANG      | COMPUTE FIELDS AT SHELTER LEVELS FOR WRF
!> 2004-12-09 | H CHUANG      | ADD ADDITIONAL LSM FIELDS
!> 2005-07-07 | BINBIN ZHOU   | ADD RSM MODEL
!> 2005-08-24 | GEOFF MANIKIN | ADDED DOMINANT PRECIP TYPE
!> 2011-02-06 | JUN WANG  | ADDED GRIB2 OPTION
!> 2013-08-05 | S Moorthi | Eliminate unnecessary arrays (reduce memory) and some cosmetic changes
!> 2014-02-26 | S Moorthi | threading datapd assignment
!> 2014-11-26 | S Moorthi | cleanup and some bug fix (may be?)
!> 2020-03-25 | J MENG    | remove grib1
!> 2020-05-20 | J MENG    | CALRH unification with NAM scheme
!> 2020-11-10 | J MENG    | USE UPP_PHYSICS MODULE
!> 2021-03-11 | B Cui     | change local arrays to dimension (im,jsta:jend)
!> 2021-04-01 | J MENG    | COMPUTATION ON DEFINED POINTS ONLY
!> 2021-07-26 | W Meng    | Restrict computation from undefined grids
!> 2021-10-31 | J MENG    | 2D DECOMPOSITION
!> 2022-02-01 | E JAMES   | Cleaning up GRIB2 encoding for six variables that cause issues with newer wgrib2 builds in RRFS system.
!> 2022-11-16 | E JAMES   | Adding dust from RRFS
!> 2022-12-23 | E Aligo   | Read six winter weather diagnostics from model.
!> 2023-01-24 | Sam Trahan | store hourly accumulated precip for IFI and bucket time
!> 2023-02-11 | W Meng     | Add fix of time accumulation in bucket graupel for FV3 based models
!> 2023-02-23 | E James    | Adding coarse PM from RRFS
!> 2023-03-22 | S Trahan   | Fixed out-of-bounds access calling BOUND with wrong array dimensions
!> 2023-04-21 | E James    | Enabling GSL precip type for RRFS
!> 2023-05-19 | E James    | Cleaning up GRIB2 encoding for 1-h max precip rate
!> 2023-06-15 | E James    | Correcting bug fix in GSL precip type for RRFS (use 1h pcp, not run total pcp)
!> 2023-10-04 | W Meng     | Fix mismatched IDs from 526-530
!> 2023-10-05 | E James    | Correcting bug fix in GSL precip type for RRFS (was using 1000x 1h pcp)
!> 2024-01-23 | E James    | Using consistent snow ratio SR from history files throughout GSL precip type diagnosis.
!> 2024-01-30 | A Jensen   | Comment out graupel precipitation warning. 
!> 2024-02-07 | E James    | Enabling output of LAI and wilting point for RRFS.
!> 2024-03-25 | E James    | Enabling output of column integrated soil moisture.
!>     
!> @note
!> USAGE:    CALL SURFCE
!> @note
!> OUTPUT FILES:
!>   NONE
!> @note
!> SUBPROGRAMS CALLED:
!>   UTILITIES:
!>     @li BOUND    - ENFORCE LOWER AND UPPER LIMITS ON ARRAY ELEMENTS.
!>     @li DEWPOINT - COMPUTE DEWPOINT TEMPERATURE.
!>     @li CALDRG   - COMPUTE SURFACE LAYER DRAG COEFFICENT
!>     @li CALTAU   - COMPUTE SURFACE LAYER U AND V WIND STRESSES.
!> @note
!>   LIBRARY:
!>     COMMON   - @li CTLBLK
!>                @li RQSTFLD
!>
!--------------------------------------------------------------------
!> SURFCE posts surface-based fields.
      SUBROUTINE SURFCE

!
!     
!     INCLUDE GRID DIMENSIONS.  SET/DERIVE OTHER PARAMETERS.
!
      use vrbls4d, only: smoke, fv3dust, coarsepm
      use vrbls3d, only: zint, pint, t, pmid, q, f_rimef
      use vrbls2d, only: ths, qs, qvg, qv2m, tsnow, tg, smstav, smstot,       &
                         cmc, sno, snoavg, psfcavg, t10avg, snonc, ivgtyp,    &
                         si, potevp, dzice, qwbs, vegfrc, isltyp, pshltr,     &
                         tshltr, qshltr, mrshltr, maxtshltr, mintshltr,       &
                         maxrhshltr, minrhshltr, u10, psfcavg, v10, u10max,   &
                         v10max, th10, t10m, q10, wspd10max,                  &
                         wspd10umax, wspd10vmax, prec, sr,                    &
                         cprate, avgcprate, avgprec, acprec, cuprec, ancprc,  &
                         lspa, acsnow, acsnom, snowfall,ssroff, bgroff,       &
                         runoff, pcp_bucket, rainnc_bucket, snow_bucket,      &
                         snownc, tmax, graup_bucket, graupelnc, qrmax, sfclhx,&
                         rainc_bucket, sfcshx, subshx, snopcx, sfcuvx,        &
                         sfcvx, smcwlt, suntime, pd, sfcux, sfcuxi, sfcvxi, sfcevp, z0,   &
                         ustar, mdltaux, mdltauy, gtaux, gtauy, twbs,         &
                         sfcexc, grnflx, islope, czmean, czen, rswin,akhsavg ,&
                         akmsavg, u10h, v10h,snfden,sndepac,qvl1,             &
                         spduv10mean,swradmean,swnormmean,prate_max,fprate_max &
                         ,fieldcapa,edir,ecan,etrans,esnow,U10mean,V10mean,   &
                         avgedir,avgecan,avgetrans,avgesnow,acgraup,acfrain,  &
                         acond,maxqshltr,minqshltr,avgpotevp,AVGPREC_CONT,    &
                         AVGCPRATE_CONT,sst,pcp_bucket1,rainnc_bucket1,       &
                         snow_bucket1, rainc_bucket1, graup_bucket1,          &
                         frzrn_bucket, snow_acm, snow_bkt,                    &
                         shdmin, shdmax, lai, ch10,cd10,landfrac,paha,pahi,   &
                         tecan,tetran,tedir,twa,IFI_APCP,xlaixy
      use soil,    only: stc, sllevel, sldpth, smc, sh2o
      use masks,   only: lmh, sm, sice, htm, gdlat, gdlon
      use physcons_post,only: CON_EPS, CON_EPSM1
      use params_mod, only: p1000, capa, h1m12, pq0, a2,a3, a4, h1, d00, d01,&
                            eps, oneps, d001, h99999, h100, small, h10e5,    &
                            elocp, g, xlai, tfrz, rd
      use ctlblk_mod, only: jsta, jend, lm, spval, grib, cfld, fld_info,     &
                            datapd, nsoil, isf_surface_physics, tprec, ifmin,&
                            modelname, tmaxmin, pthresh, dtq2, dt, nphs,     &
                            ifhr, prec_acc_dt, sdat, ihrst, jsta_2l, jend_2u,&
                            lp1, imp_physics, me, asrfc, tsrfc, pt, pdtop,   &
                            mpi_comm_comp, im, jm, prec_acc_dt1,             &
                            ista, iend, ista_2l, iend_2u
      use rqstfld_mod, only: iget, lvls, id, iavblfld, lvlsxml
      use grib2_module, only: read_grib2_head, read_grib2_sngle
      use upp_physics, only: fpvsnew, CALRH
!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
       implicit none
!
      INCLUDE "mpif.h"
!     
!     IN NGM SUBROUTINE OUTPUT WE FIND THE FOLLOWING COMMENT.
!     "IF THE FOLLOWING THRESHOLD VALUES ARE CHANGED, CONTACT
!     TDL/SYNOPTIC-SCALE TECHNIQUES BRANCH (PAUL DALLAVALLE
!     AND JOHN JENSENIUS).  THEY MAY BE USING IT IN ONE OF 
!     THEIR PACKING CODES."  THE THRESHOLD VALUE IS 0.01 INCH
!     OR 2.54E-4 METER.  PRECIPITATION VALUES LESS THAN THIS
!     THRESHOLD ARE SET TO MINUS ONE TIMES THIS THRESHOLD.
      real,PARAMETER :: PTRACE = 0.000254E0
!     
!     SET CELCIUS TO KELVIN AND SECOND TO HOUR CONVERSION.
      integer,parameter :: nalg=5, nosoiltype=9
      real,   PARAMETER :: C2K    = 273.15, SEC2HR = 1./3600.
!     
!     DECLARE VARIABLES.
!     
      integer, dimension(ista:iend,jsta:jend)  :: nroots, iwx1
      real, allocatable, dimension(:,:) :: zsfc, psfc, tsfc, qsfc,      &
                                           rhsfc, thsfc, dwpsfc, p1d,   &
                                           t1d, q1d, zwet,              &
                                           smcdry, smcmax,doms, domr,   &
                                           domip, domzr,  rsmin, smcref,&
                                           rcq, rct, rcsoil, gc, rcs
           
      real,    dimension(ista:iend,jsta:jend)       :: evp
      real,    dimension(ista_2l:iend_2u,jsta_2l:jend_2u) :: egrid1, egrid2
      real,    dimension(ista_2l:iend_2u,jsta_2l:jend_2u) :: grid2
      real,    dimension(im,jm)              :: grid1
      real,    dimension(ista_2l:iend_2u,jsta_2l:jend_2u) :: iceg
!                                   , ua, va
       real, allocatable, dimension(:,:,:)   :: sleet, rain, freezr, snow
!      real,   dimension(im,jm,nalg) :: sleet, rain, freezr, snow

!GSD
      REAL totprcp, snowratio,t2,rainl

!
      integer I,J,IWX,ITMAXMIN,IFINCR,ISVALUE,II,JJ,                    &
              ITPREC,ITSRFC,L,LS,IVEG,LLMH,                             &
              IVG,IRTN,ISEED, icat, cnt_snowratio(10),icnt_snow_rain_mixed

      real RDTPHS,TLOW,TSFCK,QSAT,DTOP,DBOT,SNEQV,RRNUM,SFCPRS,SFCQ,    &
           RC,SFCTMP,SNCOVR,FACTRS,SOLAR, s,tk,tl,w,t2c,dlt,APE,        &
           qv,e,dwpt,dum1,dum2,dum3,dum1s,dum3s,dum21,dum216,es

      character(len=256) :: ffgfile
      character(len=256) :: arifile

      logical file_exists, need_ifi

      logical, parameter :: debugprint = .false.


!****************************************************************************
!
!     START SURFCE.
!
!     
!***  BLOCK 1.  SURFACE BASED FIELDS.
!
!     IF ANY OF THE FOLLOWING "SURFACE" FIELDS ARE REQUESTED,
!     WE NEED TO COMPUTE THE FIELDS FIRST.
!     
      IF ( (IGET(024)>0).OR.(IGET(025)>0).OR.     &
           (IGET(026)>0).OR.(IGET(027)>0).OR.     &
           (IGET(028)>0).OR.(IGET(029)>0).OR.     &
           (IGET(154)>0).OR.                      &
           (IGET(034)>0).OR.(IGET(076)>0) ) THEN
!     
         allocate(zsfc(ista:iend,jsta:jend),  psfc(ista:iend,jsta:jend),  tsfc(ista:iend,jsta:jend)&
                 ,rhsfc(ista:iend,jsta:jend), thsfc(ista:iend,jsta:jend), qsfc(ista:iend,jsta:jend))
!$omp parallel do private(i,j,tsfck,qsat,es)
         DO J=JSTA,JEND
           DO I=ISTA,IEND
!
!           SCALE ARRAY FIS BY GI TO GET SURFACE HEIGHT.
!            ZSFC(I,J)=FIS(I,J)*GI

! dong add missing value for zsfc
             ZSFC(I,J)  = spval
             IF(ZINT(I,J,LM+1) < spval)                      &
             ZSFC(I,J) = ZINT(I,J,LM+1)
             PSFC(I,J) = PINT(I,J,NINT(LMH(I,J))+1)    ! SURFACE PRESSURE.
!     
!           SURFACE (SKIN) POTENTIAL TEMPERATURE AND TEMPERATURE.
             THSFC(I,J) = THS(I,J)
             TSFC(I,J)  = spval
             IF(THSFC(i,j) /= spval .and. PSFC(I,J) /= spval)   &
             TSFC(I,J) = THSFC(I,J)*(PSFC(I,J)/P1000)**CAPA 
!     
!       SURFACE SPECIFIC HUMIDITY, RELATIVE HUMIDITY, AND DEWPOINT.
!       ADJUST SPECIFIC HUMIDITY IF RELATIVE HUMIDITY EXCEEDS 0.1 OR 1.0.

! dong spfh sfc set missing value
             QSFC(I,J) = spval
             RHSFC(I,J) = spval
             EVP(I,J) = spval
             IF(TSFC(I,J) < spval) then
             IF(QS(I,J)<spval) QSFC(I,J)  = MAX(H1M12,QS(I,J))
             TSFCK      = TSFC(I,J)
     
             IF(MODELNAME == 'RAPR') THEN
                QSAT    = MAX(0.0001,PQ0/PSFC(I,J)*EXP(A2*(TSFCK-A3)/(TSFCK-A4)))
             elseif (modelname == 'GFS') then
                es      = fpvsnew(tsfck)
                qsat    = con_eps*es/(psfc(i,j)+con_epsm1*es)
             ELSE
                QSAT    = PQ0/PSFC(I,J)*EXP(A2*(TSFCK-A3)/(TSFCK-A4))
             ENDIF
             RHSFC(I,J) = max(D01, min(H1,QSFC(I,J)/QSAT))

             QSFC(I,J)  = RHSFC(I,J)*QSAT
             RHSFC(I,J) = RHSFC(I,J) * 100.0
             EVP(I,J)   = D001*PSFC(I,J)*QSFC(I,J)/(EPS+ONEPS*QSFC(I,J))
             END IF !end TSFC
!     
!mp           ACCUMULATED NON-CONVECTIVE PRECIP.
!mp            IF(IGET(034)>0)THEN
!mp              IF(LVLS(1,IGET(034))>0)THEN

!           ACCUMULATED PRECIP (convective + non-convective)
!            IF(IGET(087) > 0)THEN
!              IF(LVLS(1,IGET(087)) > 0)THEN
!                write(6,*) 'acprec, ancprc, cuprec: ', ANCPRC(I,J)+CUPREC(I,J),
!     +		 ANCPRC(I,J),CUPREC(I,J)
!                 ACPREC(I,J) = ANCPRC(I,J) + CUPREC(I,J)     ???????
!              ENDIF
!            ENDIF

           ENDDO
         ENDDO
!     
!        INTERPOLATE/OUTPUT REQUESTED SURFACE FIELDS.
!     
!        SURFACE PRESSURE.
         IF (IGET(024)>0) THEN
           if(grib == 'grib2') then
             cfld = cfld+1
             fld_info(cfld)%ifld = IAVBLFLD(IGET(024))
!$omp parallel do private(i,j,ii,jj)
             do j=1,jend-jsta+1
               jj = jsta+j-1
               do i=1,iend-ista+1
               ii = ista+i-1  
                 datapd(i,j,cfld) = PSFC(ii,jj)
               enddo
             enddo
           endif
         ENDIF
!     
!        SURFACE HEIGHT.
         IF (IGET(025)>0) THEN
!!          CALL BOUND(GRID1,D00,H99999)
            if(grib == 'grib2') then
             cfld=cfld+1
             fld_info(cfld)%ifld = IAVBLFLD(IGET(025))
!$omp parallel do private(i,j,ii,jj)
             do j=1,jend-jsta+1
               jj = jsta+j-1
               do i=1,iend-ista+1
               ii = ista+i-1
                 datapd(i,j,cfld) = ZSFC(ii,jj)
               enddo
             enddo
            endif
         ENDIF
         if (allocated(zsfc)) deallocate(zsfc)
         if (allocated(psfc)) deallocate(psfc)
!     
!        SURFACE (SKIN) TEMPERATURE.
         IF (IGET(026)>0) THEN
            if(grib == 'grib2') then
             cfld = cfld+1
             fld_info(cfld)%ifld = IAVBLFLD(IGET(026))
!$omp parallel do private(i,j,ii,jj)
             do j=1,jend-jsta+1
               jj = jsta+j-1
               do i=1,iend-ista+1
               ii = ista+i-1
                 datapd(i,j,cfld) = TSFC(ii,jj)
               enddo
             enddo
            endif
         ENDIF
         if (allocated(tsfc)) deallocate(tsfc)
!     
!        SURFACE (SKIN) POTENTIAL TEMPERATURE.
         IF (IGET(027)>0) THEN
            if(grib=='grib2') then
             cfld=cfld+1
             fld_info(cfld)%ifld=IAVBLFLD(IGET(027))
!$omp parallel do private(i,j,ii,jj)
             do j=1,jend-jsta+1
               jj = jsta+j-1
               do i=1,iend-ista+1
               ii = ista+i-1
                 datapd(i,j,cfld) = THSFC(ii,jj)
               enddo
             enddo
            endif
         ENDIF
         if (allocated(thsfc)) deallocate(thsfc)
!     
!        SURFACE SPECIFIC HUMIDITY.
         IF (IGET(028)>0) THEN
            !CALL BOUND(GRID1,H1M12,H99999)
            if(grib=='grib2') then
             cfld=cfld+1
             fld_info(cfld)%ifld=IAVBLFLD(IGET(028))
!$omp parallel do private(i,j,ii,jj)
             do j=1,jend-jsta+1
               jj = jsta+j-1
               do i=1,iend-ista+1
               ii = ista+i-1
                 datapd(i,j,cfld) = QSFC(ii,jj)
               enddo
             enddo
            endif
         ENDIF
         if (allocated(qsfc)) deallocate(qsfc)
!     
!        SURFACE DEWPOINT TEMPERATURE.
         IF (IGET(029)>0) THEN
            allocate(dwpsfc(ista:iend,jsta:jend))
            CALL DEWPOINT(EVP,DWPSFC)
            if(grib=='grib2') then
             cfld=cfld+1
             fld_info(cfld)%ifld=IAVBLFLD(IGET(029))
!$omp parallel do private(i,j,ii,jj)
             do j=1,jend-jsta+1
               jj = jsta+j-1
               do i=1,iend-ista+1
               ii = ista+i-1
                 datapd(i,j,cfld) = DWPSFC(ii,jj)
               enddo
             enddo
            endif
            if (allocated(dwpsfc)) deallocate(dwpsfc)
         ENDIF
!     
!        SURFACE RELATIVE HUMIDITY.
         IF (IGET(076)>0) THEN
            if(grib=='grib2') then
             cfld=cfld+1
             fld_info(cfld)%ifld=IAVBLFLD(IGET(076))
!$omp parallel do private(i,j,ii,jj)
             do j=1,jend-jsta+1
               jj = jsta+j-1
               do i=1,iend-ista+1
               ii = ista+i-1
               if(RHSFC(ii,jj) /= spval) then
                 datapd(i,j,cfld) = max(H1,min(H100,RHSFC(ii,jj)))
               else
                 datapd(i,j,cfld) = spval
               endif
               enddo
             enddo
            endif
         ENDIF
        if (allocated(rhsfc)) deallocate(rhsfc)
!     
      ENDIF

!     ADDITIONAL SURFACE-SOIL LEVEL FIELDS.
!
!     SURFACE MIXING RATIO
      IF (IGET(762)>0) THEN
        if(grib=='grib2') then
          cfld=cfld+1
          fld_info(cfld)%ifld=IAVBLFLD(IGET(762))
!$omp parallel do private(i,j,ii,jj)
          do j=1,jend-jsta+1
            jj = jsta+j-1
            do i=1,iend-ista+1
            ii = ista+i-1
              datapd(i,j,cfld) =  QVG(ii,jj)
            enddo
          enddo
        endif
      ENDIF
!    

!     SHELTER MIXING RATIO
      IF (IGET(760)>0) THEN
        if(grib=='grib2') then
          cfld=cfld+1
          fld_info(cfld)%ifld=IAVBLFLD(IGET(760))
!$omp parallel do private(i,j,ii,jj)
          do j=1,jend-jsta+1
            jj = jsta+j-1
            do i=1,iend-ista+1
            ii = ista+i-1
              datapd(i,j,cfld) = QV2M(ii,jj)
            enddo
          enddo
        endif
      ENDIF

!     SNOW TEMERATURE
      IF (IGET(761)>0) THEN
        if(grib=='grib2') then
          cfld=cfld+1
          fld_info(cfld)%ifld=IAVBLFLD(IGET(761))
!$omp parallel do private(i,j,ii,jj)
          do j=1,jend-jsta+1
            jj = jsta+j-1
            do i=1,iend-ista+1
            ii = ista+i-1
              datapd(i,j,cfld) =  TSNOW(ii,jj)
            enddo
          enddo
        endif
      ENDIF

!     DENSITY OF SNOWFALL
      IF (IGET(724)>0) THEN
           if(grib=='grib2') then
             cfld=cfld+1
             fld_info(cfld)%ifld=IAVBLFLD(IGET(724))
!$omp parallel do private(i,j,ii,jj)
             do j=1,jend-jsta+1
               jj = jsta+j-1
               do i=1,iend-ista+1
               ii = ista+i-1
                 datapd(i,j,cfld) =  SNFDEN(ii,jj)
               enddo
             enddo
           endif
      ENDIF

!     ACCUMULATED DEPTH OF SNOWFALL
      IF (IGET(725)>0) THEN
         ID(1:25) = 0
         ITPREC     = NINT(TPREC)
!mp
         IF(ITPREC /= 0) THEN
            IFINCR = MOD(IFHR,ITPREC)
            IF(IFMIN >= 1)IFINCR = MOD(IFHR*60+IFMIN,ITPREC*60)
         ELSE 
           IFINCR = 0
         ENDIF
!mp
         ID(18)     = 0
         ID(19)     = IFHR
         IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
         ID(20)     = 4
         IF (IFINCR==0) THEN
           ID(18) = IFHR-ITPREC
         ELSE 
           ID(18) = IFHR-IFINCR
           IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
         ENDIF
         IF (ID(18)<0) ID(18) = 0
         if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(725))
            fld_info(cfld)%ntrange=1
            fld_info(cfld)%tinvstat=IFHR
!$omp parallel do private(i,j,ii,jj)
            do j=1,jend-jsta+1
              jj = jsta+j-1
              do i=1,iend-ista+1
              ii = ista+i-1
              if(SNDEPAC(ii,jj)<spval) then
                if(MODELNAME=='FV3R') then
                  datapd(i,j,cfld) = SNDEPAC(ii,jj)/(1E3)
                else
                  datapd(i,j,cfld) = SNDEPAC(ii,jj) 
                endif
              else
                datapd(i,j,cfld) = spval
              endif
              enddo
            enddo
         endif
      ENDIF

!
!     ADDITIONAL SURFACE-SOIL LEVEL FIELDS.
!
!      print *,'in surf,nsoil=',nsoil,'iget(116)=',iget(116),    &
!       'lvls(116)=',LVLS(1:4,IGET(116)),  &
!        'sf_sfc_phys=',iSF_SURFACE_PHYSICS

      DO L=1,NSOIL
!       SOIL TEMPERATURE.
        IF (IGET(116)>0) THEN
          IF (LVLS(L,IGET(116))>0) THEN
            IF(iSF_SURFACE_PHYSICS==3)THEN
              if(grib=='grib2') then
                cfld=cfld+1
                fld_info(cfld)%ifld=IAVBLFLD(IGET(116))
                fld_info(cfld)%lvl=LVLSXML(L,IGET(116))
!$omp parallel do private(i,j,ii,jj)
                do j=1,jend-jsta+1
                  jj = jsta+j-1
                  do i=1,iend-ista+1
                  ii = ista+i-1
                    datapd(i,j,cfld) = STC(ii,jj,l)
                  enddo
                enddo
              endif

            ELSE

              DTOP = 0.
              DO LS=1,L-1
                DTOP = DTOP + SLDPTH(LS)
              ENDDO
              DBOT = DTOP + SLDPTH(L)
              if(grib=='grib2') then
                cfld=cfld+1
                fld_info(cfld)%ifld=IAVBLFLD(IGET(116))
                fld_info(cfld)%lvl=LVLSXML(L,IGET(116))
!$omp parallel do private(i,j,ii,jj)
                do j=1,jend-jsta+1
                  jj = jsta+j-1
                  do i=1,iend-ista+1
                  ii = ista+i-1
                    datapd(i,j,cfld) = STC(ii,jj,l)
                  enddo
                enddo
              endif

            ENDIF
          ENDIF
        ENDIF
!
!     SOIL MOISTURE.
        IF (IGET(117)>0) THEN
          IF (LVLS(L,IGET(117))>0) THEN
            IF(iSF_SURFACE_PHYSICS==3)THEN
              if(grib=='grib2') then
                cfld=cfld+1
                fld_info(cfld)%ifld=IAVBLFLD(IGET(117))
                fld_info(cfld)%lvl=LVLSXML(L,IGET(117))
!$omp parallel do private(i,j,ii,jj)
                do j=1,jend-jsta+1
                  jj = jsta+j-1
                  do i=1,iend-ista+1
                  ii = ista+i-1
                    datapd(i,j,cfld) = SMC(ii,jj,l)
                  enddo
                enddo
              endif
            ELSE
              DTOP = 0.
              DO LS=1,L-1
                DTOP = DTOP + SLDPTH(LS)
              ENDDO
              DBOT = DTOP + SLDPTH(L)
              if(grib=='grib2') then
                cfld=cfld+1
                fld_info(cfld)%ifld=IAVBLFLD(IGET(117))
                fld_info(cfld)%lvl=LVLSXML(L,IGET(117))
!$omp parallel do private(i,j,ii,jj)
                do j=1,jend-jsta+1
                  jj = jsta+j-1
                  do i=1,iend-ista+1
                  ii = ista+i-1
                    datapd(i,j,cfld) = SMC(ii,jj,l)
                  enddo
                enddo
              endif
            ENDIF
          ENDIF
        ENDIF
!     ADD LIQUID SOIL MOISTURE
        IF (IGET(225)>0) THEN
          IF (LVLS(L,IGET(225))>0) THEN
            IF(iSF_SURFACE_PHYSICS==3)THEN
              if(grib=='grib2') then
               cfld=cfld+1
               fld_info(cfld)%ifld=IAVBLFLD(IGET(225))
               fld_info(cfld)%lvl=LVLSXML(L,IGET(225))
!$omp parallel do private(i,j,ii,jj)
               do j=1,jend-jsta+1
                 jj = jsta+j-1
                 do i=1,iend-ista+1
                 ii = ista+i-1
                   datapd(i,j,cfld) = SH2O(ii,jj,l)
                 enddo
               enddo
              endif
            ELSE
              DTOP = 0.
              DO LS=1,L-1
                DTOP = DTOP + SLDPTH(LS)
              ENDDO
              DBOT = DTOP + SLDPTH(L)
              if(grib=='grib2') then
                cfld=cfld+1
                fld_info(cfld)%ifld=IAVBLFLD(IGET(225))
                fld_info(cfld)%lvl=LVLSXML(L,IGET(225))
!$omp parallel do private(i,j,ii,jj)
                do j=1,jend-jsta+1
                  jj = jsta+j-1
                  do i=1,iend-ista+1
                  ii = ista+i-1
                    datapd(i,j,cfld) = SH2O(ii,jj,l)
                  enddo
                enddo
              endif
            ENDIF
          ENDIF
        ENDIF
      ENDDO                   ! END OF NSOIL LOOP
!                               -----------------
!
!     BOTTOM SOIL TEMPERATURE.
      IF (IGET(115)>0.or.IGET(571)>0) THEN
        if(iget(115)>0) then
          if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(115))
!$omp parallel do private(i,j,ii,jj)
            do j=1,jend-jsta+1
              jj = jsta+j-1
              do i=1,iend-ista+1
              ii = ista+i-1
                datapd(i,j,cfld) = TG(ii,jj)
              enddo
            enddo
          endif
        endif
        if(iget(571)>0.and.grib=='grib2') then
          cfld=cfld+1
          fld_info(cfld)%ifld=IAVBLFLD(IGET(571))
!$omp parallel do private(i,j,ii,jj)
          do j=1,jend-jsta+1
            jj = jsta+j-1
            do i=1,iend-ista+1
            ii = ista+i-1
              datapd(i,j,cfld) = TG(ii,jj)
            enddo
          enddo
        endif
      ENDIF
!
!     SOIL MOISTURE AVAILABILITY
      IF (IGET(171)>0) THEN
!!$omp parallel do private(i,j)
        DO J=JSTA,JEND
          DO I=ISTA,IEND
            IF(SMSTAV(I,J) /= SPVAL)THEN
              IF ( MODELNAME == 'FV3R') THEN
                GRID1(I,J) = SMSTAV(I,J)
              ELSE
                GRID1(I,J) = SMSTAV(I,J)*100.
              ENDIF
            ELSE
              GRID1(I,J) = 0.
            ENDIF
          ENDDO
        ENDDO
        if(grib=='grib2') then
          cfld=cfld+1
          fld_info(cfld)%ifld=IAVBLFLD(IGET(171))
!$omp parallel do private(i,j,ii,jj)
          do j=1,jend-jsta+1
            jj = jsta+j-1
            do i=1,iend-ista+1
            ii = ista+i-1
              datapd(i,j,cfld) = GRID1(ii,jj)
            enddo
          enddo
        endif
      ENDIF
!
!     TOTAL SOIL MOISTURE
      IF (IGET(036)>0) THEN
!$omp parallel do private(i,j)
         DO J=JSTA,JEND
           DO I=ISTA,IEND
             IF(SMSTOT(I,J)/=SPVAL) THEN
               IF(SM(I,J) > SMALL .AND. SICE(I,J) < SMALL) THEN
                 GRID1(I,J) = 1000.0  ! TEMPORY FIX TO MAKE SURE SMSTOT=1 FOR WATER
               ELSE  
                 GRID1(I,J) = SMSTOT(I,J)
               END IF 
             ELSE
               GRID1(I,J) = 1000.0
             ENDIF
           ENDDO
         ENDDO
         if(grib=='grib2') then
          cfld=cfld+1
          fld_info(cfld)%ifld=IAVBLFLD(IGET(036))
!$omp parallel do private(i,j,ii,jj)
          do j=1,jend-jsta+1
            jj = jsta+j-1
            do i=1,iend-ista+1
            ii = ista+i-1
              datapd(i,j,cfld) = GRID1(ii,jj)
            enddo
          enddo
         endif
      ENDIF
!
!     TOTAL SOIL MOISTURE
      IF (IGET(713)>0) THEN
!$omp parallel do private(i,j)
         DO J=JSTA,JEND
           DO I=ISTA,IEND
!             IF(SMSTOT(I,J)/=SPVAL) THEN
               GRID1(I,J) = SMSTOT(I,J)
!             ELSE
!               GRID1(I,J) = SPVAL
!             ENDIF
           ENDDO
         ENDDO
         if(grib=='grib2') then
          cfld=cfld+1
          fld_info(cfld)%ifld=IAVBLFLD(IGET(713))
!$omp parallel do private(i,j,ii,jj)
          do j=1,jend-jsta+1
            jj = jsta+j-1
            do i=1,iend-ista+1
            ii = ista+i-1
              datapd(i,j,cfld) = GRID1(ii,jj)
            enddo
          enddo
         endif
      ENDIF
!
!     PLANT CANOPY SURFACE WATER.
      IF ( IGET(118)>0 ) THEN
        IF(MODELNAME == 'RAPR') THEN
!$omp parallel do private(i,j)
          DO J=JSTA,JEND
            DO I=ISTA,IEND
              IF(CMC(I,J) /= SPVAL) then
                GRID1(I,J) = CMC(I,J)
              else
                GRID1(I,J) = spval
              endif
            ENDDO
          ENDDO
        else
!$omp parallel do private(i,j)
          DO J=JSTA,JEND
            DO I=ISTA,IEND
              IF(CMC(I,J) /= SPVAL) then
                GRID1(I,J) = CMC(I,J)*1000.
              else
                GRID1(I,J) = spval
              endif
            ENDDO
          ENDDO
        endif
         if(grib=='grib2') then
          cfld=cfld+1
          fld_info(cfld)%ifld=IAVBLFLD(IGET(118))
!$omp parallel do private(i,j,ii,jj)
          do j=1,jend-jsta+1
            jj = jsta+j-1
            do i=1,iend-ista+1
            ii = ista+i-1
              datapd(i,j,cfld) = GRID1(ii,jj)
            enddo
          enddo
         endif
      ENDIF
!
!     SNOW WATER EQUIVALENT.
      IF ( IGET(119)>0 ) THEN
!       GRID1 = SPVAL
        if(grib=='grib2') then
          cfld=cfld+1
          fld_info(cfld)%ifld=IAVBLFLD(IGET(119))
!$omp parallel do private(i,j,ii,jj)
          do j=1,jend-jsta+1
            jj = jsta+j-1
            do i=1,iend-ista+1
            ii = ista+i-1
              datapd(i,j,cfld) = SNO(ii,jj)
            enddo
          enddo
        endiF
      ENDIF
!
!     Time averaged percent SNOW COVER (for AQ)
      IF ( IGET(500)>0 ) THEN
!       GRID1=SPVAL
!$omp parallel do private(i,j)
        DO J=JSTA,JEND
          DO I=ISTA,IEND
!            GRID1(I,J) = 100.*SNOAVG(I,J)
            GRID1(I,J) = SNOAVG(I,J)
            if (SNOAVG(I,J) /= spval) GRID1(I,J) = 100.*SNOAVG(I,J)
          ENDDO
        ENDDO
        CALL BOUND(GRID1,D00,H100)
        ID(1:25) = 0
        ITSRFC     = NINT(TSRFC)
        IF(ITSRFC /= 0) then
         IFINCR     = MOD(IFHR,ITSRFC)
         IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITSRFC*60)
        ELSE
         IFINCR     = 0
        endif
        ID(19)     = IFHR
        IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
        ID(20)     = 3
        IF (IFINCR==0) THEN
           ID(18) = IFHR-ITSRFC
        ELSE
           ID(18) = IFHR-IFINCR
           IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
        ENDIF
        IF (ID(18)<0) ID(18) = 0
        if(grib=='grib2') then
           cfld=cfld+1
           fld_info(cfld)%ifld=IAVBLFLD(IGET(500))
           if(ITSRFC>0) then
            fld_info(cfld)%ntrange=1
           else
            fld_info(cfld)%ntrange=0
           endif
           fld_info(cfld)%tinvstat=IFHR-ID(18)
          ! fld_info(cfld)%ntrange=IFHR-ID(18)
          ! fld_info(cfld)%tinvstat=1
!$omp parallel do private(i,j,ii,jj)
           do j=1,jend-jsta+1
             jj = jsta+j-1
             do i=1,iend-ista+1
             ii = ista+i-1
               datapd(i,j,cfld) = GRID1(ii,jj)
             enddo
           enddo
        endif
      ENDIF

!     Time averaged surface pressure (for AQ)
      IF ( IGET(501)>0 ) THEN
!       GRID1 = SPVAL
        ID(1:25) = 0
        ID(19)     = IFHR
        IF (IFHR==0) THEN
          ID(18) = 0
        ELSE
          ID(18) = IFHR - 1
        ENDIF
        ID(20)     = 3
        ITSRFC = NINT(TSRFC)
        if(grib=='grib2') then
          cfld=cfld+1
          fld_info(cfld)%ifld=IAVBLFLD(IGET(501))
            if(ITSRFC>0) then
              fld_info(cfld)%ntrange=1
            else
              fld_info(cfld)%ntrange=0
            endif
            fld_info(cfld)%tinvstat=IFHR-ID(18)
!$omp parallel do private(i,j,ii,jj)
          do j=1,jend-jsta+1
            jj = jsta+j-1
            do i=1,iend-ista+1
            ii = ista+i-1
              datapd(i,j,cfld) = PSFCAVG(ii,jj)
            enddo
          enddo
        endif
      ENDIF

!     Time averaged 10 m temperature (for AQ)
      IF ( IGET(502)>0 ) THEN
!       GRID1 = SPVAL
        ID(1:25) = 0
        ID(19)     = IFHR
        IF (IFHR==0) THEN
          ID(18) = 0
        ELSE
          ID(18) = IFHR - 1
        ENDIF
        ID(20)     = 3
        ISVALUE = 10
        ID(10) = MOD(ISVALUE/256,256)
        ID(11) = MOD(ISVALUE,256)
        ITSRFC = NINT(TSRFC)
        if(grib=='grib2') then
          cfld=cfld+1
          fld_info(cfld)%ifld=IAVBLFLD(IGET(502))
            if(ITSRFC>0) then
              fld_info(cfld)%ntrange=1
            else
              fld_info(cfld)%ntrange=0
            endif
            fld_info(cfld)%tinvstat=IFHR-ID(18)
!$omp parallel do private(i,j,ii,jj)
          do j=1,jend-jsta+1
            jj = jsta+j-1
            do i=1,iend-ista+1
            ii = ista+i-1
              datapd(i,j,cfld) = T10AVG(ii,jj)
            enddo
          enddo
        endif
      ENDIF
!
!     ACM GRID SCALE SNOW AND ICE
      IF ( IGET(244)>0 ) THEN
!$omp parallel do private(i,j)
        DO J=JSTA,JEND
          DO I=ISTA,IEND
            GRID1(I,J) = SNONC(I,J)
          ENDDO
        ENDDO
        ID(1:25) = 0
        ITPREC     = NINT(TPREC)
!mp
        if (ITPREC /= 0) then
          IFINCR     = MOD(IFHR,ITPREC)
          IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITPREC*60)
        else
          IFINCR     = 0
        endif
!mp
        ID(18)     = 0
        ID(19)     = IFHR
        IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
        ID(20)     = 4
        IF (IFINCR==0) THEN
          ID(18) = IFHR-ITPREC
        ELSE
          ID(18) = IFHR-IFINCR
          IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
        ENDIF
        IF (ID(18)<0) ID(18) = 0

         if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(244))
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
         endif
      ENDIF
!
!     PERCENT SNOW COVER.
      IF ( IGET(120)>0 ) THEN
        GRID1=SPVAL
        DO J=JSTA,JEND
          DO I=ISTA,IEND
!           GRID1(I,J)=PCTSNO(I,J)
            IF ( SNO(I,J) /= SPVAL ) THEN
            SNEQV = SNO(I,J)
            IVEG  = IVGTYP(I,J)
            IF(IVEG==0)IVEG=7
            CALL SNFRAC (SNEQV,IVEG,SNCOVR)
            GRID1(I,J) = SNCOVR*100.
            ENDIF
          ENDDO
        ENDDO
        CALL BOUND(GRID1,D00,H100)
        if(grib=='grib2') then
          cfld=cfld+1
          fld_info(cfld)%ifld=IAVBLFLD(IGET(120))
!$omp parallel do private(i,j,ii,jj)
          do j=1,jend-jsta+1
            jj = jsta+j-1
            do i=1,iend-ista+1
            ii = ista+i-1
              datapd(i,j,cfld) = GRID1(ii,jj)
            enddo
          enddo
        endif
      ENDIF
! ADD SNOW DEPTH
      IF ( IGET(224)>0 ) THEN
        ii = (ista+iend)/2
        jj = (jsta+jend)/2
!       GRID1=SPVAL
!$omp parallel do private(i,j)
        DO J=JSTA,JEND
          DO I=ISTA,IEND
            GRID1(I,J) = SPVAL
            IF(SI(I,J) /= SPVAL) GRID1(I,J) = SI(I,J)*0.001  ! SI comes out of WRF in mm
          ENDDO
        ENDDO
!        print*,'sample snow depth in GRIBIT= ',si(ii,jj)
        if(grib=='grib2') then
          cfld=cfld+1
          fld_info(cfld)%ifld=IAVBLFLD(IGET(224))
!$omp parallel do private(i,j,ii,jj)
          do j=1,jend-jsta+1
            jj = jsta+j-1
            do i=1,iend-ista+1
            ii = ista+i-1
              datapd(i,j,cfld) = GRID1(ii,jj)
            enddo
          enddo
        endif
      ENDIF      
! ADD POTENTIAL EVAPORATION
      IF ( IGET(242)>0 ) THEN
        if(grib=='grib2') then
          cfld=cfld+1
          fld_info(cfld)%ifld=IAVBLFLD(IGET(242))
!$omp parallel do private(i,j,ii,jj)
          do j=1,jend-jsta+1
            jj = jsta+j-1
            do i=1,iend-ista+1
            ii = ista+i-1
              datapd(i,j,cfld) = POTEVP(ii,jj)
            enddo
          enddo
        endif
      ENDIF
! ADD ICE THICKNESS
      IF ( IGET(349)>0 ) THEN
        if(grib=='grib2') then
          cfld=cfld+1
          fld_info(cfld)%ifld=IAVBLFLD(IGET(349))
!$omp parallel do private(i,j,ii,jj)
          do j=1,jend-jsta+1
            jj = jsta+j-1
            do i=1,iend-ista+1
            ii = ista+i-1
              datapd(i,j,cfld) = DZICE(ii,jj)
            enddo
          enddo
        endif
      ENDIF      

! ADD EC,EDIR,ETRANS,ESNOW,SMCDRY,SMCMAX
! ONLY OUTPUT NEW LSM FIELDS FOR NMM AND ARW BECAUSE RSM USES OLD SOIL TYPES
      IF (MODELNAME == 'NCAR'.OR. MODELNAME == 'NMM'                  &
        .OR. MODELNAME == 'FV3R' .OR. MODELNAME == 'RAPR') THEN
!       write(*,*)'in surf,isltyp=',maxval(isltyp(1:im,jsta:jend)),   &
!         minval(isltyp(1:im,jsta:jend)),'qwbs=',maxval(qwbs(1:im,jsta:jend)), &
!         minval(qwbs(1:im,jsta:jend)),'potsvp=',maxval(potevp(1:im,jsta:jend)), &
!         minval(potevp(1:im,jsta:jend)),'sno=',maxval(sno(1:im,jsta:jend)), &
!         minval(sno(1:im,jsta:jend)),'vegfrc=',maxval(vegfrc(1:im,jsta:jend)), &
!         minval(vegfrc(1:im,jsta:jend)), 'sh2o=',maxval(sh2o(1:im,jsta:jend,1)), &
!         minval(sh2o(1:im,jsta:jend,1)),'cmc=',maxval(cmc(1:im,jsta:jend)), &
!         minval(cmc(1:im,jsta:jend))
        IF ( IGET(228)>0 .OR. IGET(229)>0      &
         .OR.IGET(230)>0 .OR. IGET(231)>0      &
         .OR.IGET(232)>0 .OR. IGET(233)>0) THEN

          allocate(smcdry(ista:iend,jsta:jend), &
                   smcmax(ista:iend,jsta:jend))
          DO J=JSTA,JEND
            DO I=ISTA,IEND
! ----------------------------------------------------------------------
!             IF(QWBS(I,J)>0.001)print*,'NONZERO QWBS',i,j,QWBS(I,J)
!             IF(abs(SM(I,J)-0.)<1.0E-5)THEN
! WRF ARW has no POTEVP field. So has to block out RAPR
              IF( (MODELNAME/='RAPR') .AND. (abs(SM(I,J)-0.)   < 1.0E-5) .AND.   &
     &        (abs(SICE(I,J)-0.) < 1.0E-5) ) THEN
                 CALL ETCALC(QWBS(I,J),POTEVP(I,J),SNO(I,J),VEGFRC(I,J) &
     &                ,  ISLTYP(I,J),SH2O(I,J,1:1),CMC(I,J)         &
     &                ,  ECAN(I,J),EDIR(I,J),ETRANS(I,J),ESNOW(I,J) &
     &                ,  SMCDRY(I,J),SMCMAX(I,J) )
              ELSE
                ECAN(I,J)   = 0.
                EDIR(I,J)   = 0.
                ETRANS(I,J) = 0.
                ESNOW(I,J)  = 0.
                SMCDRY(I,J) = 0.
                SMCMAX(I,J) = 0.
              ENDIF
            ENDDO
          ENDDO

          IF ( IGET(228)>0 )THEN
            if(grib=='grib2') then
              cfld=cfld+1
              fld_info(cfld)%ifld=IAVBLFLD(IGET(228))
!$omp parallel do private(i,j,ii,jj)
              do j=1,jend-jsta+1
                jj = jsta+j-1
                do i=1,iend-ista+1
                ii = ista+i-1
                 datapd(i,j,cfld) = ECAN(ii,jj)
                enddo
              enddo
            endiF
          ENDIF

          IF ( IGET(229)>0 )THEN
            if(grib=='grib2') then
              cfld=cfld+1
              fld_info(cfld)%ifld=IAVBLFLD(IGET(229))
!$omp parallel do private(i,j,ii,jj)
              do j=1,jend-jsta+1
                jj = jsta+j-1
                do i=1,iend-ista+1
                ii = ista+i-1
                  datapd(i,j,cfld) = EDIR(ii,jj)
                enddo
              enddo
            endif
          ENDIF

          IF ( IGET(230)>0 )THEN
            if(grib=='grib2') then
              cfld=cfld+1
              fld_info(cfld)%ifld=IAVBLFLD(IGET(230))
              datapd(1:iend-ista+1,1:jend-jsta+1,cfld) = ETRANS(ista:iend,jsta:jend)
            endif
          ENDIF

          IF ( IGET(231)>0 )THEN
            if(grib=='grib2') then
              cfld=cfld+1
              fld_info(cfld)%ifld=IAVBLFLD(IGET(231))
              datapd(1:iend-ista+1,1:jend-jsta+1,cfld) = ESNOW(ista:iend,jsta:jend)
            endif
          ENDIF

          IF ( IGET(232)>0 )THEN
            if(grib=='grib2') then
              cfld=cfld+1
              fld_info(cfld)%ifld=IAVBLFLD(IGET(232))
!$omp parallel do private(i,j,ii,jj)
              do j=1,jend-jsta+1
                jj = jsta+j-1
                do i=1,iend-ista+1
                ii = ista+i-1
                  datapd(i,j,cfld) = SMCDRY(ii,jj)
                enddo
              enddo
            endif
          ENDIF

          IF ( IGET(233)>0 )THEN
            if(grib=='grib2') then
              cfld=cfld+1
              fld_info(cfld)%ifld=IAVBLFLD(IGET(233))
!$omp parallel do private(i,j,ii,jj)
              do j=1,jend-jsta+1
                 jj = jsta+j-1
                 do i=1,iend-ista+1
                 ii = ista+i-1
                 datapd(i,j,cfld) = SMCMAX(ii,jj)
                enddo
              enddo
            endif
          ENDIF

        ENDIF
!        if (allocated(ecan))   deallocate(ecan)
!        if (allocated(edir))   deallocate(edir)
!        if (allocated(etrans)) deallocate(etrans)
!        if (allocated(esnow))  deallocate(esnow)
        if (allocated(smcdry)) deallocate(smcdry)
        if (allocated(smcmax)) deallocate(smcmax)

      END IF  ! endif for ncar and nmm options

      IF ( IGET(512)>0 )THEN
          if(grib=='grib2') then
              cfld=cfld+1
              fld_info(cfld)%ifld=IAVBLFLD(IGET(512))
!$omp parallel do private(i,j,ii,jj)
              do j=1,jend-jsta+1
                jj = jsta+j-1
                do i=1,iend-ista+1
                ii = ista+i-1
                  datapd(i,j,cfld) = acond(ii,jj)
                enddo
              enddo
          endiF
      ENDIF

      IF ( IGET(513)>0 )THEN
          ID(1:25) = 0
          ITSRFC     = NINT(TSRFC)
          IF(ITSRFC /= 0) then
           IFINCR     = MOD(IFHR,ITSRFC)
           IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITSRFC*60)
          ELSE
           IFINCR     = 0
          endif
          ID(19)     = IFHR
          IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
          ID(20)     = 3
          IF (IFINCR==0) THEN
             ID(18) = IFHR-ITSRFC
          ELSE
             ID(18) = IFHR-IFINCR
             IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
          ENDIF
          IF (ID(18)<0) ID(18) = 0
          if(grib=='grib2') then
              cfld=cfld+1
              fld_info(cfld)%ifld=IAVBLFLD(IGET(513))
              if(ITSRFC>0) then
               fld_info(cfld)%ntrange=1
              else
               fld_info(cfld)%ntrange=0
              endif
              fld_info(cfld)%tinvstat=IFHR-ID(18)
!$omp parallel do private(i,j,ii,jj)
              do j=1,jend-jsta+1
                jj = jsta+j-1
                do i=1,iend-ista+1
                ii = ista+i-1
                  datapd(i,j,cfld) = avgECAN(ii,jj)
                enddo
              enddo
          endiF
      ENDIF

      IF ( IGET(514)>0 )THEN
          ID(1:25) = 0
          ITSRFC     = NINT(TSRFC)
          IF(ITSRFC /= 0) then
           IFINCR     = MOD(IFHR,ITSRFC)
           IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITSRFC*60)
          ELSE
           IFINCR     = 0
          endif
          ID(19)     = IFHR
          IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
          ID(20)     = 3
          IF (IFINCR==0) THEN
             ID(18) = IFHR-ITSRFC
          ELSE
             ID(18) = IFHR-IFINCR
             IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
          ENDIF
          IF (ID(18)<0) ID(18) = 0
          if(grib=='grib2') then
              cfld=cfld+1
              fld_info(cfld)%ifld=IAVBLFLD(IGET(514))
              if(ITSRFC>0) then
               fld_info(cfld)%ntrange=1
              else
               fld_info(cfld)%ntrange=0
              endif
              fld_info(cfld)%tinvstat=IFHR-ID(18)
!$omp parallel do private(i,j,ii,jj)
              do j=1,jend-jsta+1
                jj = jsta+j-1
                do i=1,iend-ista+1
                ii = ista+i-1
                  datapd(i,j,cfld) = avgEDIR(ii,jj)
                enddo
              enddo
          endif
      ENDIF

      IF ( IGET(515)>0 )THEN
          ID(1:25) = 0
          ITSRFC     = NINT(TSRFC)
          IF(ITSRFC /= 0) then
           IFINCR     = MOD(IFHR,ITSRFC)
           IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITSRFC*60)
          ELSE
           IFINCR     = 0
          endif
          ID(19)     = IFHR
          IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
          ID(20)     = 3
          IF (IFINCR==0) THEN
             ID(18) = IFHR-ITSRFC
          ELSE
             ID(18) = IFHR-IFINCR
             IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
          ENDIF
          IF (ID(18)<0) ID(18) = 0
          if(grib=='grib2') then
              cfld=cfld+1
              fld_info(cfld)%ifld=IAVBLFLD(IGET(515))
              if(ITSRFC>0) then
               fld_info(cfld)%ntrange=1
              else
               fld_info(cfld)%ntrange=0
              endif
              fld_info(cfld)%tinvstat=IFHR-ID(18)
              datapd(1:iend-ista+1,1:jend-jsta+1,cfld) = avgETRANS(ista:iend,jsta:jend)
          endif
      ENDIF

      IF ( IGET(516)>0 )THEN
          ID(1:25) = 0
          ITSRFC     = NINT(TSRFC)
          IF(ITSRFC /= 0) then
           IFINCR     = MOD(IFHR,ITSRFC)
           IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITSRFC*60)
          ELSE
           IFINCR     = 0
          endif
          ID(19)     = IFHR
          IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
          ID(20)     = 3
          IF (IFINCR==0) THEN
             ID(18) = IFHR-ITSRFC
          ELSE
             ID(18) = IFHR-IFINCR
             IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
          ENDIF
          IF (ID(18)<0) ID(18) = 0
          if(grib=='grib2') then
              cfld=cfld+1
              fld_info(cfld)%ifld=IAVBLFLD(IGET(516))
               if(ITSRFC>0) then
               fld_info(cfld)%ntrange=1
              else
               fld_info(cfld)%ntrange=0
              endif
              fld_info(cfld)%tinvstat=IFHR-ID(18)
              datapd(1:iend-ista+1,1:jend-jsta+1,cfld) = avgESNOW(ista:iend,jsta:jend)
          endif
      ENDIF

          IF ( IGET(996)>0 )THEN
            if(grib=='grib2') then
              cfld=cfld+1
              fld_info(cfld)%ifld=IAVBLFLD(IGET(996))
!$omp parallel do private(i,j,ii,jj)
              do j=1,jend-jsta+1
                jj = jsta+j-1
                do i=1,iend-ista+1
                ii = ista+i-1
                  datapd(i,j,cfld) = LANDFRAC(ii,jj)
                enddo
              enddo
            endif
          ENDIF

          IF ( IGET(997)>0 )THEN
            if(grib=='grib2') then
              cfld=cfld+1
              fld_info(cfld)%ifld=IAVBLFLD(IGET(997))
!$omp parallel do private(i,j,ii,jj)
              do j=1,jend-jsta+1
                jj = jsta+j-1
                do i=1,iend-ista+1
                ii = ista+i-1
                  datapd(i,j,cfld) = PAHI(ii,jj)
                enddo
              enddo
            endif
          ENDIF

          IF ( IGET(998)>0 )THEN
            if(grib=='grib2') then
              cfld=cfld+1
              fld_info(cfld)%ifld=IAVBLFLD(IGET(998))
!$omp parallel do private(i,j,ii,jj)
              do j=1,jend-jsta+1
                jj = jsta+j-1
                do i=1,iend-ista+1
                ii = ista+i-1
                  datapd(i,j,cfld) = TWA(ii,jj)
                enddo
              enddo
            endif
          ENDIF

          IF ( IGET(999)>0 )THEN
!$omp parallel do private(i,j)
         DO J=JSTA,JEND
           DO I=ISTA,IEND
             GRID1(I,J) = TECAN(I,J)
           ENDDO
         ENDDO
         ID(1:25) = 0
         ITPREC     = NINT(TPREC)
         if (ITPREC /= 0) then
           IFINCR     = MOD(IFHR,ITPREC)
           IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITPREC*60)
         else
           IFINCR     = 0
         endif
         ID(18)     = 0
         ID(19)     = IFHR
         IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
         ID(20)     = 4
         IF (IFINCR==0) THEN
           ID(18) = IFHR-ITPREC
         ELSE
           ID(18) = IFHR-IFINCR
           IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
         ENDIF
         IF (ID(18)<0) ID(18) = 0
        if(grib=='grib2') then
          cfld=cfld+1
           fld_info(cfld)%ifld=IAVBLFLD(IGET(999))
           fld_info(cfld)%ntrange=1
          fld_info(cfld)%tinvstat=IFHR-ID(18)
!$omp parallel do private(i,j,ii,jj)
              do j=1,jend-jsta+1
                jj = jsta+j-1
                do i=1,iend-ista+1
                ii = ista+i-1
                  datapd(i,j,cfld) = GRID1(ii,jj)
                enddo
              enddo
            endif
          ENDIF

          IF ( IGET(1000)>0 )THEN
!$omp parallel do private(i,j)
         DO J=JSTA,JEND
           DO I=ISTA,IEND
             GRID1(I,J) = TETRAN(I,J)
           ENDDO
         ENDDO
         ID(1:25) = 0
         ITPREC     = NINT(TPREC)
         if (ITPREC /= 0) then
           IFINCR     = MOD(IFHR,ITPREC)
           IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITPREC*60)
         else
           IFINCR     = 0
         endif
         ID(18)     = 0
         ID(19)     = IFHR
         IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
         ID(20)     = 4
         IF (IFINCR==0) THEN
           ID(18) = IFHR-ITPREC
         ELSE
           ID(18) = IFHR-IFINCR
           IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
         ENDIF
         IF (ID(18)<0) ID(18) = 0
        if(grib=='grib2') then
          cfld=cfld+1
           fld_info(cfld)%ifld=IAVBLFLD(IGET(1000))
           fld_info(cfld)%ntrange=1
          fld_info(cfld)%tinvstat=IFHR-ID(18)
!$omp parallel do private(i,j,ii,jj)
          do j=1,jend-jsta+1
            jj = jsta+j-1
            do i=1,iend-ista+1
                ii = ista+i-1
              datapd(i,j,cfld) = GRID1(ii,jj)
            enddo
          enddo
        endif
      ENDIF
!
          IF ( IGET(1001)>0 )THEN
!$omp parallel do private(i,j)
         DO J=JSTA,JEND
           DO I=ISTA,IEND
             GRID1(I,J) = TEDIR(I,J)
           ENDDO
         ENDDO
         ID(1:25) = 0
         ITPREC     = NINT(TPREC)
         if (ITPREC /= 0) then
           IFINCR     = MOD(IFHR,ITPREC)
           IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITPREC*60)
         else
           IFINCR     = 0
         endif
         ID(18)     = 0
         ID(19)     = IFHR
         IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
         ID(20)     = 4
         IF (IFINCR==0) THEN
           ID(18) = IFHR-ITPREC
         ELSE
           ID(18) = IFHR-IFINCR
           IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
         ENDIF
         IF (ID(18)<0) ID(18) = 0
        if(grib=='grib2') then
          cfld=cfld+1
           fld_info(cfld)%ifld=IAVBLFLD(IGET(1001))
           fld_info(cfld)%ntrange=1
          fld_info(cfld)%tinvstat=IFHR-ID(18)
!$omp parallel do private(i,j,ii,jj)
          do j=1,jend-jsta+1
            jj = jsta+j-1
            do i=1,iend-ista+1
            ii = ista+i-1
              datapd(i,j,cfld) = GRID1(ii,jj)
            enddo
          enddo
        endif
      ENDIF
!

         IF (IGET(1002)>0) THEN
            IF(ASRFC>0.)THEN
              RRNUM=1./ASRFC
            ELSE
              RRNUM=0.
            ENDIF
            DO J=JSTA,JEND
            DO I=ISTA,IEND
             IF(PAHA(I,J)/=SPVAL)THEN
              GRID1(I,J)=-1.*PAHA(I,J)*RRNUM !change the sign to conform with Grib
             ELSE
              GRID1(I,J)=PAHA(I,J)
             END IF
            ENDDO
            ENDDO
            ID(1:25) = 0
            ITSRFC     = NINT(TSRFC)
            IF(ITSRFC /= 0) then
             IFINCR     = MOD(IFHR,ITSRFC)
             IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITSRFC*60)
            ELSE
             IFINCR     = 0
            endif
            ID(19)     = IFHR
            IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
            ID(20)     = 3
            IF (IFINCR==0) THEN
               ID(18) = IFHR-ITSRFC
            ELSE
               ID(18) = IFHR-IFINCR
               IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
            ENDIF
            IF (ID(18)<0) ID(18) = 0
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(1002))
            if(ITSRFC>0) then
               fld_info(cfld)%ntrange=1
            else
               fld_info(cfld)%ntrange=0
            endif
            fld_info(cfld)%tinvstat=IFHR-ID(18)
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
           endif
         ENDIF
!
!     
!
!***  BLOCK 2.  SHELTER (2M) LEVEL FIELDS.
!     
!     COMPUTE/POST SHELTER LEVEL FIELDS.
!     
      IF ( (IGET(106)>0).OR.(IGET(112)>0).OR.     &
           (IGET(113)>0).OR.(IGET(114)>0).OR.     &
           (IGET(138)>0).OR.(IGET(414)>0).OR.     &
           (IGET(546)>0).OR.(IGET(547)>0).OR.     &
           (IGET(548)>0).OR.(IGET(739)>0).OR.     &
           (IGET(744)>0).OR.(IGET(771)>0)) THEN

        if (.not. allocated(psfc))  allocate(psfc(ista:iend,jsta:jend))
!
!HC  COMPUTE SHELTER PRESSURE BECAUSE IT WAS NOT OUTPUT FROM WRF       
        IF(MODELNAME == 'NCAR' .OR. MODELNAME=='RSM'.OR. MODELNAME=='RAPR')THEN
          DO J=JSTA,JEND
            DO I=ISTA,IEND
              TLOW        = T(I,J,NINT(LMH(I,J)))
              PSFC(I,J)   = PINT(I,J,NINT(LMH(I,J))+1)   !May not have been set above
              PSHLTR(I,J) = PSFC(I,J)*EXP(-0.068283/TLOW)
            ENDDO
          ENDDO 
        ENDIF 
!
!        print *,'in, surfc,pshltr=',maxval(PSHLTR(1:im,jsta:jend)),  &
!           minval(PSHLTR(1:im,jsta:jend)),PSHLTR(1:3,jsta),'capa=',capa, &
!           'tshlter=',tshltr(1:3,jsta:jsta+2),'psfc=',psfc(1:3,jsta:jsta+2), &
!           'th10=',th10(1:3,jsta:jsta+2),'thz0=',thz0(1:3,jsta:jsta+2)
!
!        SHELTER LEVEL TEMPERATURE
        IF (IGET(106)>0) THEN
           GRID1=SPVAL
           DO J=JSTA,JEND
             DO I=ISTA,IEND
!              GRID1(I,J)=TSHLTR(I,J)
!HC CONVERT FROM THETA TO T 
               if(tshltr(i,j)/=spval)GRID1(I,J)=TSHLTR(I,J)*(PSHLTR(I,J)*1.E-5)**CAPA
               IF(GRID1(I,J)<200)PRINT*,'ABNORMAL 2MT ',i,j,  &
                   TSHLTR(I,J),PSHLTR(I,J)
!                  TSHLTR(I,J)=GRID1(I,J) 
             ENDDO
           ENDDO
!          print *,'2m tmp=',maxval(TSHLTR(ista:iend,jsta:jend)), &
!             minval(TSHLTR(ista:iend,jsta:jend)),TSHLTR(1:3,jsta),'grd=',grid1(1:3,jsta)
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(106))
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld) = GRID1(ista:iend,jsta:jend)
           endif
        ENDIF
!
!        SHELTER LEVEL POT TEMP
        IF (IGET(546)>0) THEN
!          GRID1=spval
!          DO J=JSTA,JEND
!            DO I=ISTA,IEND
!              GRID1(I,J)=TSHLTR(I,J)
!            ENDDO
!          ENDDO
           if(grib=='grib2') then
             cfld=cfld+1
             fld_info(cfld)%ifld=IAVBLFLD(IGET(546))
             datapd(1:iend-ista+1,1:jend-jsta+1,cfld) = TSHLTR(ista:iend,jsta:jend)
           endif
        ENDIF
!
!        SHELTER LEVEL SPECIFIC HUMIDITY.
        IF (IGET(112)>0) THEN       
           DO J=JSTA,JEND
             DO I=ISTA,IEND
               GRID1(I,J) = QSHLTR(I,J)
             ENDDO
           ENDDO
           CALL BOUND (GRID1,H1M12,H99999)
           if(grib=='grib2') then
             cfld=cfld+1
             fld_info(cfld)%ifld=IAVBLFLD(IGET(112))
             datapd(1:iend-ista+1,1:jend-jsta+1,cfld) = GRID1(ista:iend,jsta:jend)
           endif
        ENDIF
!     GRID1
!        SHELTER MIXING RATIO.
        IF (IGET(414)>0) THEN
           DO J=JSTA,JEND
             DO I=ISTA,IEND
               GRID1(I,J) = MRSHLTR(I,J)
             ENDDO
           ENDDO
         if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(414))
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
         endif
        ENDIF
!
!        SHELTER LEVEL DEWPOINT, DEWPOINT DEPRESSION AND SFC EQUIV POT TEMP.
           allocate(p1d(ista:iend,jsta:jend), t1d(ista:iend,jsta:jend))
        IF ((IGET(113)>0) .OR.(IGET(547)>0).OR.(IGET(548)>0)) THEN

           DO J=JSTA,JEND
             DO I=ISTA,IEND

!tgs The next 4 lines are GSD algorithm for Dew Point computation
!tgs Results are very close to dew point computed in DEWPOINT subroutine
               qv   = max(1.E-5,(QSHLTR(I,J)/(1.-QSHLTR(I,J))))
               e    = PSHLTR(I,J)/100.*qv/(0.62197+qv)
               DWPT = (243.5*LOG(E)-440.8)/(19.48-LOG(E))+273.15

!              if(i==335.and.j==295)print*,'Debug: RUC-type DEWPT,i,j'  &
!              if(i==ii.and.j==jj)print*,'Debug: RUC-type DEWPT,i,j'
!              ,   DWPT,i,j,qv,pshltr(i,j),qshltr(i,j)

!              EGRID1(I,J) = DWPT

               IF(QSHLTR(I,J)<spval.and.PSHLTR(I,J)<spval)THEN
               EVP(I,J) = PSHLTR(I,J)*QSHLTR(I,J)/(EPS+ONEPS*QSHLTR(I,J))
               EVP(I,J) = EVP(I,J)*D001
               ELSE
               EVP(I,J) = spval
               ENDIF
             ENDDO
           ENDDO
           CALL DEWPOINT(EVP,EGRID1(ista:iend,jsta:jend))
!      print *,' MAX DEWPOINT',maxval(egrid1)
! DEWPOINT
           IF (IGET(113)>0) THEN
             GRID1=spval
             if(MODELNAME=='RAPR')THEN
               DO J=JSTA,JEND
               DO I=ISTA,IEND
! DEWPOINT can't be higher than T2
                t2=TSHLTR(I,J)*(PSHLTR(I,J)*1.E-5)**CAPA
                if(qshltr(i,j)/=spval)GRID1(I,J)=min(EGRID1(I,J),T2)
               ENDDO
               ENDDO
             else
               DO J=JSTA,JEND
               DO I=ISTA,IEND
                if(qshltr(i,j)/=spval) GRID1(I,J) = EGRID1(I,J)
               ENDDO
               ENDDO
             endif
             if(grib=='grib2') then
               cfld=cfld+1
               fld_info(cfld)%ifld=IAVBLFLD(IGET(113))
                datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
             endif
           ENDIF


!-------------------------------------------------------------------------
! DEWPOINT at level 1   ------ p1d and t1d are  undefined !! -- Moorthi
           IF (IGET(771)>0) THEN
             DO J=JSTA,JEND
               DO I=ISTA,IEND
                 EVP(I,J)=P1D(I,J)*QVl1(I,J)/(EPS+ONEPS*QVl1(I,J))
                 EVP(I,J)=EVP(I,J)*D001
               ENDDO
             ENDDO
             CALL DEWPOINT(EVP,EGRID1(ista:iend,jsta:jend))
!             print *,' MAX DEWPOINT at level 1',maxval(egrid1)
             GRID1=spval
             DO J=JSTA,JEND
               DO I=ISTA,IEND
!tgs 30 dec 2013 - 1st leel dewpoint can't be higher than 1-st level temperature
                 if(qvl1(i,j)/=spval)GRID1(I,J) = min(EGRID1(I,J),T1D(I,J))
               ENDDO
             ENDDO
             if(grib=='grib2') then
               cfld=cfld+1
               fld_info(cfld)%ifld=IAVBLFLD(IGET(771))
               datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
             endif
           ENDIF
!-------------------------------------------------------------------------

!
           IF ((IGET(547)>0).OR.(IGET(548)>0)) THEN
            GRID1=SPVAL
            GRID2=SPVAL
            DO J=JSTA,JEND
            DO I=ISTA,IEND
            if(TSHLTR(I,J)/=spval.and.PSHLTR(I,J)/=spval.and.QSHLTR(I,J)/=spval) then
! DEWPOINT DEPRESSION in GRID1
             GRID1(i,j)=max(0.,TSHLTR(I,J)*(PSHLTR(I,J)*1.E-5)**CAPA-EGRID1(i,j))

! SURFACE EQIV POT TEMP in GRID2
             APE=(H10E5/PSHLTR(I,J))**CAPA
             GRID2(I,J)=TSHLTR(I,J)*EXP(ELOCP*QSHLTR(I,J)*APE/TSHLTR(I,J))
            endif 
            ENDDO
            ENDDO
!       print *,' MAX/MIN --> DEWPOINT DEPRESSION',maxval(grid1(1:im,jsta:jend)),&
!                                                  minval(grid1(1:im,jsta:jend))
!       print *,' MAX/MIN -->  SFC EQUIV POT TEMP',maxval(grid2(1:im,jsta:jend)),&
!                                                  minval(grid2(1:im,jsta:jend))

             IF (IGET(547)>0) THEN
               if(grib=='grib2') then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(547))
                 datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
               endif

             ENDIF
             IF (IGET(548)>0) THEN
               if(grib=='grib2') then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(548))
                 datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID2(ista:iend,jsta:jend)
               endif
             ENDIF
           ENDIF


         ENDIF
!     
!        SHELTER LEVEL RELATIVE HUMIDITY AND APPARENT TEMPERATURE
         IF (IGET(114) > 0 .OR. IGET(808) > 0) THEN
           allocate(q1d(ista:iend,jsta:jend))
!$omp parallel do private(i,j,llmh)
           DO J=JSTA,JEND
             DO I=ISTA,IEND
               IF(MODELNAME=='RAPR')THEN
                 LLMH = NINT(LMH(I,J))
!                P1D(I,J)=PINT(I,J,LLMH+1)
                 P1D(I,J) = PMID(I,J,LLMH)
                 T1D(I,J) = T(I,J,LLMH)
               ELSE
                 P1D(I,J) = PSHLTR(I,J)
                 T1D(I,J) = TSHLTR(I,J)*(PSHLTR(I,J)*1.E-5)**CAPA
               ENDIF
               Q1D(I,J) = QSHLTR(I,J)
             ENDDO
           ENDDO

           CALL CALRH(P1D,T1D,Q1D,EGRID1(ista:iend,jsta:jend))

           if (allocated(q1d)) deallocate(q1d)
!$omp parallel do private(i,j)
           DO J=JSTA,JEND
             DO I=ISTA,IEND
               if(qshltr(i,j) /= spval)then
                 GRID1(I,J) = EGRID1(I,J)*100.
               else
                 grid1(i,j) = spval 
               end if 
             ENDDO
           ENDDO
           CALL BOUND(GRID1,H1,H100)
           IF (IGET(114) > 0) THEN
             if(grib == 'grib2') then
                cfld = cfld+1
                fld_info(cfld)%ifld = IAVBLFLD(IGET(114))
!$omp parallel do private(i,j,ii,jj)
                do j=1,jend-jsta+1
                  jj = jsta+j-1
                  do i=1,iend-ista+1
                  ii = ista+i-1
                    datapd(i,j,cfld) = GRID1(ii,jj)
                  enddo
                enddo
             endif
           ENDIF

           IF(IGET(808)>0)THEN
             GRID2=SPVAL
!$omp parallel do private(i,j,dum1,dum2,dum3,dum216,dum1s,dum3s)
             DO J=JSTA,JEND
               DO I=ISTA,IEND
               if(T1D(I,J)/=spval.and.U10H(I,J)/=spval.and.V10H(I,J)<spval) then
                 DUM1 = (T1D(I,J)-TFRZ)*1.8+32.
                 DUM2 = SQRT(U10H(I,J)**2.0+V10H(I,J)**2.0)/0.44704
                 DUM3 = EGRID1(I,J) * 100.0
!                if(abs(gdlon(i,j)-120.)<1. .and. abs(gdlat(i,j))<1.)         &
!                  print*,'Debug AT: INPUT', T1D(i,j),dum1,dum2,dum3
                 IF(DUM1 <= 50.) THEN
                   DUM216 = DUM2**0.16
                   GRID2(I,J) = 35.74 + 0.6215*DUM1                           &
                              - 35.75*DUM216 + 0.4275*DUM1*DUM216
                   GRID2(I,J) =(GRID2(I,J)-32.)/1.8+TFRZ
                 ELSE IF(DUM1 > 80.) THEN
                   DUM1S = DUM1*DUM1
                   DUM3S = DUM3*DUM3
                   GRID2(I,J) = -42.379 + 2.04901523*DUM1                     &
                              + 10.14333127*DUM3                              &
                              - 0.22475541*DUM1*DUM3                          &
                              - 0.00683783*DUM1S                              &
                              - 0.05481717*DUM3S                              &
                              + 0.00122874*DUM1S*DUM3                         &
                              + 0.00085282*DUM1*DUM3S                         &
                              - 0.00000199*DUM1S*DUM3S
                   GRID2(I,J) = (GRID2(I,J)-32.)/1.8 + TFRZ
                 ELSE
                   GRID2(I,J) = T1D(I,J)
                 END IF
!                if(abs(gdlon(i,j)-120.)<1. .and. abs(gdlat(i,j))<1.) &
!                 print*,'Debug AT: OUTPUT',Grid2(i,j)
               endif
               ENDDO
             ENDDO

             if(grib == 'grib2') then
               cfld = cfld+1
               fld_info(cfld)%ifld = IAVBLFLD(IGET(808))
!$omp parallel do private(i,j,ii,jj)
                do j=1,jend-jsta+1
                  jj = jsta+j-1
                  do i=1,iend-ista+1
                  ii = ista+i-1
                    datapd(i,j,cfld) = GRID2(ii,jj)
                  enddo
                enddo
             endif

           ENDIF !for 808

         ENDIF ! ENDIF for shleter RH or apparent T

         if (allocated(p1d)) deallocate (p1d)
         if (allocated(t1d)) deallocate (t1d)
!     
!        SHELTER LEVEL PRESSURE.
         IF (IGET(138)>0) THEN
!          DO J=JSTA,JEND
!            DO I=ISTA,IEND
!              GRID1(I,J)=PSHLTR(I,J)
!            ENDDO
!          ENDDO
           if(grib=='grib2') then
             cfld=cfld+1
             fld_info(cfld)%ifld=IAVBLFLD(IGET(138))
!$omp parallel do private(i,j,ii,jj)
             do j=1,jend-jsta+1
               jj = jsta+j-1
               do i=1,iend-ista+1
               ii = ista+i-1
                 datapd(i,j,cfld) = PSHLTR(ii,jj)
               enddo
             enddo
           endif
         ENDIF
!
      ENDIF
!
!        SHELTER LEVEL MAX TEMPERATURE.
         IF (IGET(345)>0) THEN       
!          DO J=JSTA,JEND
!            DO I=ISTA,IEND
!              GRID1(I,J)=MAXTSHLTR(I,J)
!            ENDDO
!          ENDDO
!mp
           TMAXMIN = MAX(TMAXMIN,1.)
!mp
           ITMAXMIN = INT(TMAXMIN)
           IF(ITMAXMIN /= 0) then
             IFINCR     = MOD(IFHR,ITMAXMIN)
	     IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITMAXMIN*60)
	   ELSE
	     IFINCR     = 0
           endif
           ID(19)     = IFHR
	   IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
           ID(20)     = 2
           IF (IFINCR==0) THEN
              ID(18) = IFHR-ITMAXMIN
           ELSE
              ID(18) = IFHR-IFINCR
	      IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
           ENDIF
           IF (ID(18)<0) ID(18) = 0
           if(grib=='grib2') then
             cfld=cfld+1
             fld_info(cfld)%ifld=IAVBLFLD(IGET(345))
             if(ITMAXMIN==0) then
               fld_info(cfld)%ntrange=0
             else
               fld_info(cfld)%ntrange=1
             endif
             fld_info(cfld)%tinvstat=IFHR-ID(18)
             if(IFHR==0) fld_info(cfld)%tinvstat=0
!$omp parallel do private(i,j,ii,jj)
             do j=1,jend-jsta+1
               jj = jsta+j-1
               do i=1,iend-ista+1
               ii = ista+i-1
                 datapd(i,j,cfld) =  MAXTSHLTR(ii,jj)
               enddo
             enddo
           endif
         ENDIF
!
!        SHELTER LEVEL MIN TEMPERATURE.
         IF (IGET(346)>0) THEN       
!!$omp parallel do private(i,j)
!          DO J=JSTA,JEND
!            DO I=ISTA,IEND
!              GRID1(I,J) = MINTSHLTR(I,J)
!            ENDDO
!          ENDDO
           ID(1:25) = 0
           ITMAXMIN     = INT(TMAXMIN)
           IF(ITMAXMIN /= 0) then
             IFINCR     = MOD(IFHR,ITMAXMIN)
             IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITMAXMIN*60)
           ELSE
             IFINCR     = 0
           endif
           ID(19)     = IFHR
           IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
           ID(20)     = 2
           IF (IFINCR==0) THEN
             ID(18) = IFHR-ITMAXMIN
           ELSE
             ID(18) = IFHR-IFINCR
             IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
           ENDIF
           IF (ID(18)<0) ID(18) = 0
           if(grib=='grib2') then
             cfld=cfld+1
             fld_info(cfld)%ifld=IAVBLFLD(IGET(346))
             if(ITMAXMIN==0) then
               fld_info(cfld)%ntrange=0
             else
               fld_info(cfld)%ntrange=1
             endif
             fld_info(cfld)%tinvstat=IFHR-ID(18)
             if(IFHR==0) fld_info(cfld)%tinvstat=0
!$omp parallel do private(i,j,ii,jj)
             do j=1,jend-jsta+1
               jj = jsta+j-1
               do i=1,iend-ista+1
               ii = ista+i-1
                 datapd(i,j,cfld) = MINTSHLTR(ii,jj)
               enddo
             enddo
           endif
         ENDIF
!
!        SHELTER LEVEL MAX RH.
         IF (IGET(347)>0) THEN       
         GRID1=SPVAL
            DO J=JSTA,JEND
            DO I=ISTA,IEND
             if(MAXRHSHLTR(I,J)/=spval) GRID1(I,J)=MAXRHSHLTR(I,J)*100.
            ENDDO
            ENDDO
	    ID(1:25) = 0
	    ID(02)=129
	    ITMAXMIN     = INT(TMAXMIN)
            IF(ITMAXMIN /= 0) then
             IFINCR     = MOD(IFHR,ITMAXMIN)
	     IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITMAXMIN*60)
	    ELSE
	     IFINCR     = 0
            endif
            ID(19)     = IFHR
	    IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
            ID(20)     = 2
            IF (IFINCR==0) THEN
               ID(18) = IFHR-ITMAXMIN
            ELSE
               ID(18) = IFHR-IFINCR
               IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
            ENDIF
            IF (ID(18)<0) ID(18) = 0
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(347))
            if(ITMAXMIN==0) then
              fld_info(cfld)%ntrange=0
            else
!Meng 03/2019
!              fld_info(cfld)%ntrange=(IFHR-ID(18))/ITMAXMIN
              fld_info(cfld)%ntrange=1
            endif
!            fld_info(cfld)%tinvstat=ITMAXMIN
            fld_info(cfld)%tinvstat=IFHR-ID(18)
            if(IFHR==0) fld_info(cfld)%tinvstat=0
!            print*,'id(18),tinvstat,IFHR,ITMAXMIN in rhmax= ',ID(18),fld_info(cfld)%tinvstat, &
!                IFHR, ITMAXMIN
!$omp parallel do private(i,j,ii,jj)
            do j=1,jend-jsta+1
              jj = jsta+j-1
              do i=1,iend-ista+1
              ii = ista+i-1
                datapd(i,j,cfld) = GRID1(ii,jj)
              enddo
            enddo
           endif
         ENDIF
!
!        SHELTER LEVEL MIN RH.
         IF (IGET(348)>0) THEN       
            GRID1=SPVAL
            DO J=JSTA,JEND
            DO I=ISTA,IEND
             if(MINRHSHLTR(I,J)/=spval) GRID1(I,J)=MINRHSHLTR(I,J)*100.
            ENDDO
            ENDDO
	    ID(1:25) = 0
	    ID(02)=129
	    ITMAXMIN     = INT(TMAXMIN)
            IF(ITMAXMIN /= 0) then
             IFINCR     = MOD(IFHR,ITMAXMIN)
	     IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITMAXMIN*60)
	    ELSE
	     IFINCR     = 0
            endif
            ID(19)     = IFHR
	    IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
            ID(20)     = 2
            IF (IFINCR==0) THEN
               ID(18) = IFHR-ITMAXMIN
            ELSE
               ID(18) = IFHR-IFINCR
               IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
            ENDIF
            IF (ID(18)<0) ID(18) = 0
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(348))
            if(ITMAXMIN==0) then
              fld_info(cfld)%ntrange=0
            else
!Meng 03/2019
!              fld_info(cfld)%ntrange=(IFHR-ID(18))/ITMAXMIN
              fld_info(cfld)%ntrange=1
            endif
!            fld_info(cfld)%tinvstat=ITMAXMIN
            fld_info(cfld)%tinvstat=IFHR-ID(18)
            if(IFHR==0) fld_info(cfld)%tinvstat=0
!$omp parallel do private(i,j,ii,jj)
            do j=1,jend-jsta+1
              jj = jsta+j-1
              do i=1,iend-ista+1
              ii = ista+i-1
                datapd(i,j,cfld) = GRID1(ii,jj)
              enddo
            enddo
           endif
         ENDIF

!
!        SHELTER LEVEL MAX SPFH 
         IF (IGET(510)>0) THEN
            ID(1:25) = 0
            ITMAXMIN     = INT(TMAXMIN)
            IF(ITMAXMIN /= 0) then
             IFINCR     = MOD(IFHR,ITMAXMIN)
             IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITMAXMIN*60)
            ELSE
             IFINCR     = 0
            endif
            ID(19)     = IFHR
            IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
            ID(20)     = 2
            IF (IFINCR==0) THEN
               ID(18) = IFHR-ITMAXMIN
            ELSE
               ID(18) = IFHR-IFINCR
               IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
            ENDIF
            IF (ID(18)<0) ID(18) = 0
            if(grib=='grib2') then
              cfld=cfld+1
              fld_info(cfld)%ifld=IAVBLFLD(IGET(510))
              if(ITMAXMIN==0) then
                fld_info(cfld)%ntrange=0
              else
                fld_info(cfld)%ntrange=1
              endif
              fld_info(cfld)%tinvstat=IFHR-ID(18)
!$omp parallel do private(i,j,ii,jj)
              do j=1,jend-jsta+1
                jj = jsta+j-1
                do i=1,iend-ista+1
                ii = ista+i-1
                  datapd(i,j,cfld) = maxqshltr(ii,jj)
                enddo
              enddo
            endif
         ENDIF
!
!        SHELTER LEVEL MIN SPFH
         IF (IGET(511)>0) THEN
            ID(1:25) = 0
            ITMAXMIN     = INT(TMAXMIN)
            IF(ITMAXMIN /= 0) then
             IFINCR     = MOD(IFHR,ITMAXMIN)
             IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITMAXMIN*60)
            ELSE
             IFINCR     = 0
            endif
            ID(19)     = IFHR
            IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
            ID(20)     = 2
            IF (IFINCR==0) THEN
               ID(18) = IFHR-ITMAXMIN
            ELSE
               ID(18) = IFHR-IFINCR
               IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
            ENDIF
            IF (ID(18)<0) ID(18) = 0
            if(grib=='grib2') then
              cfld=cfld+1
              fld_info(cfld)%ifld=IAVBLFLD(IGET(511))
              if(ITMAXMIN==0) then
                fld_info(cfld)%ntrange=0
              else
                fld_info(cfld)%ntrange=1
              endif
              fld_info(cfld)%tinvstat=IFHR-ID(18)
!$omp parallel do private(i,j,ii,jj)
              do j=1,jend-jsta+1
                jj = jsta+j-1
                do i=1,iend-ista+1
                ii = ista+i-1
                  datapd(i,j,cfld) = minqshltr(ii,jj)
                enddo
              enddo
            endif
         ENDIF
!
! E. James - 12 Sep 2018: SMOKE from WRF-CHEM on lowest model level
!
         IF (IGET(739)>0) THEN
           GRID1=SPVAL
           DO J=JSTA,JEND
             DO I=ISTA,IEND
             if(T(I,J,LM)/=spval.and.PMID(I,J,LM)/=spval.and.SMOKE(I,J,LM,1)/=spval)&
               GRID1(I,J) = (1./RD)*(PMID(I,J,LM)/T(I,J,LM))*SMOKE(I,J,LM,1)/(1E9)
             ENDDO
           ENDDO
           if(grib=='grib2') then
             cfld=cfld+1
             fld_info(cfld)%ifld=IAVBLFLD(IGET(739))
             datapd(1:iend-ista+1,1:jend-jsta+1,cfld) = GRID1(ista:iend,jsta:jend)
           endif
         ENDIF
!
! E. James - 14 Sep 2022: DUST from RRFS on lowest model level
!
         IF (IGET(744)>0) THEN
           GRID1=SPVAL
           DO J=JSTA,JEND
             DO I=ISTA,IEND
             if(T(I,J,LM)/=spval.and.PMID(I,J,LM)/=spval.and.FV3DUST(I,J,LM,1)/=spval)&
               GRID1(I,J) = (1./RD)*(PMID(I,J,LM)/T(I,J,LM))*FV3DUST(I,J,LM,1)/(1E9)
             ENDDO
           ENDDO
           if(grib=='grib2') then
             cfld=cfld+1
             fld_info(cfld)%ifld=IAVBLFLD(IGET(744))
             datapd(1:iend-ista+1,1:jend-jsta+1,cfld) = GRID1(ista:iend,jsta:jend)
           endif
         ENDIF
!
! E. James - 23 Feb 2023: COARSEPM from RRFS on lowest model level
!
         IF (IGET(1014)>0) THEN
           GRID1=SPVAL
           DO J=JSTA,JEND
             DO I=ISTA,IEND
             if(T(I,J,LM)/=spval.and.PMID(I,J,LM)/=spval.and.COARSEPM(I,J,LM,1)/=spval)&
               GRID1(I,J) = (1./RD)*(PMID(I,J,LM)/T(I,J,LM))*COARSEPM(I,J,LM,1)/(1E9)
             ENDDO
           ENDDO
           if(grib=='grib2') then
             cfld=cfld+1
             fld_info(cfld)%ifld=IAVBLFLD(IGET(1014))
             datapd(1:iend-ista+1,1:jend-jsta+1,cfld) = GRID1(ista:iend,jsta:jend)
           endif
         ENDIF
!
!
!     BLOCK 3.  ANEMOMETER LEVEL (10M) WINDS, THETA, AND Q.
!
      IF ( (IGET(064)>0).OR.(IGET(065)>0).OR. &
           (IGET(506)>0).OR.(IGET(507)>0)  ) THEN
!
!        ANEMOMETER LEVEL U WIND AND/OR V WIND.
         IF ((IGET(064)>0).OR.(IGET(065)>0)) THEN
!$omp parallel do private(i,j)
           DO J=JSTA,JEND
             DO I=ISTA,IEND
               GRID1(I,J) = U10(I,J)
               GRID2(I,J) = V10(I,J)
             ENDDO
           ENDDO
           if(grib=='grib2') then
             cfld=cfld+1
             fld_info(cfld)%ifld=IAVBLFLD(IGET(064))
!$omp parallel do private(i,j,ii,jj)
             do j=1,jend-jsta+1
               jj = jsta+j-1
               do i=1,iend-ista+1
               ii = ista+i-1
                 datapd(i,j,cfld) = GRID1(ii,jj)
               enddo
             enddo
             cfld=cfld+1
             fld_info(cfld)%ifld=IAVBLFLD(IGET(065))
!$omp parallel do private(i,j,ii,jj)
             do j=1,jend-jsta+1
               jj = jsta+j-1
               do i=1,iend-ista+1
               ii = ista+i-1
                 datapd(i,j,cfld) = GRID2(ii,jj)
               enddo
             enddo
           endif
         ENDIF
! GSD - Time-averaged wind speed (forecast time labels will all be in minutes)
         IF (IGET(730)>0) THEN
           IFINCR     = 5
           DO J=JSTA,JEND
           DO I=ISTA,IEND
            GRID1(I,J)=SPDUV10MEAN(I,J)
           ENDDO
           ENDDO
          if(grib=='grib2') then
!           print*,'Outputting time-averaged winds'
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(730))
            if(fld_info(cfld)%ntrange==0) then
              if (ifhr==0 .and. ifmin==0) then
                fld_info(cfld)%tinvstat=0
              else
                fld_info(cfld)%tinvstat=IFINCR
              endif
              fld_info(cfld)%ntrange=1
            end if
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
           endif
         ENDIF
!---
! GSD - Time-averaged U wind speed (forecast time labels will all be in minutes)
         IF (IGET(731)>0) THEN
           IFINCR     = 5
           DO J=JSTA,JEND
           DO I=ISTA,IEND
            GRID1(I,J)=U10MEAN(I,J)
           ENDDO
           ENDDO
           if(grib=='grib2') then 
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(731))
            if(fld_info(cfld)%ntrange==0) then 
              if (ifhr==0 .and. ifmin==0) then
                fld_info(cfld)%tinvstat=0
              else 
                fld_info(cfld)%tinvstat=IFINCR
              endif
              fld_info(cfld)%ntrange=1
            end if
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
           endif
         ENDIF
! GSD - Time-averaged V wind speed (forecast time labels will all be in minutes)
         IF (IGET(732)>0) THEN
           IFINCR     = 5 
           DO J=JSTA,JEND
           DO I=ISTA,IEND
            GRID1(I,J)=V10MEAN(I,J)
           ENDDO
           ENDDO
           if(grib=='grib2') then 
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(732))
            if(fld_info(cfld)%ntrange==0) then 
              if (ifhr==0 .and. ifmin==0) then
                fld_info(cfld)%tinvstat=0
              else
                fld_info(cfld)%tinvstat=IFINCR
              endif
              fld_info(cfld)%ntrange=1
            end if
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
           endif
         ENDIF
! Time-averaged SWDOWN (forecast time labels will all be in minutes)
         IF (IGET(733)>0 )THEN
           IFINCR     = 15
           DO J=JSTA,JEND
           DO I=ISTA,IEND
             GRID1(I,J) = SWRADMEAN(I,J)
           ENDDO
           ENDDO
           if(grib=='grib2') then 
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(733))
            if(fld_info(cfld)%ntrange==0) then
              if (ifhr==0 .and. ifmin==0) then
                fld_info(cfld)%tinvstat=0
              else
                fld_info(cfld)%tinvstat=IFINCR
              endif
              fld_info(cfld)%ntrange=1
            end if
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
           endif
         ENDIF     
! Time-averaged SWNORM (forecast time labels will all be in minutes)
         IF (IGET(734)>0 )THEN
           IFINCR     = 15
           DO J=JSTA,JEND
           DO I=ISTA,IEND
             GRID1(I,J) = SWNORMMEAN(I,J)
           ENDDO
           ENDDO
           if(grib=='grib2') then 
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(734))
            if(fld_info(cfld)%ntrange==0) then 
              if (ifhr==0 .and. ifmin==0) then
                fld_info(cfld)%tinvstat=0
              else
                fld_info(cfld)%tinvstat=IFINCR
              endif
              fld_info(cfld)%ntrange=1
            endif
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
           endif
         ENDIF
!
         IF ((IGET(506)>0).OR.(IGET(507)>0)) THEN
	    ID(02)=129
         ID(20) = 2
         ID(19) = IFHR
         IF (IFHR==0) THEN
           ID(18) = 0
         ELSE
           ID(18) = IFHR - 1
         ENDIF
!$omp parallel do private(i,j)
            DO J=JSTA,JEND
              DO I=ISTA,IEND
                GRID1(I,J) = U10MAX(I,J)
                GRID2(I,J) = V10MAX(I,J)
              ENDDO
            ENDDO
           ITSRFC = NINT(TSRFC)
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(506))
            if(ITSRFC>0) then
              fld_info(cfld)%ntrange=1
            else
              fld_info(cfld)%ntrange=0
            endif
            fld_info(cfld)%tinvstat=IFHR-ID(18)
!$omp parallel do private(i,j,ii,jj)
            do j=1,jend-jsta+1
              jj = jsta+j-1
              do i=1,iend-ista+1
              ii = ista+i-1
                datapd(i,j,cfld) = GRID1(ii,jj)
              enddo
            enddo
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(507))
            if(ITSRFC>0) then
              fld_info(cfld)%ntrange=1
            else
              fld_info(cfld)%ntrange=0
            endif
            fld_info(cfld)%tinvstat=IFHR-ID(18)
!$omp parallel do private(i,j,ii,jj)
            do j=1,jend-jsta+1
              jj = jsta+j-1
              do i=1,iend-ista+1
              ii = ista+i-1
                datapd(i,j,cfld) = GRID2(ii,jj)
              enddo
            enddo
           endif
         ENDIF

      ENDIF
!
!        ANEMOMETER LEVEL (10 M) POTENTIAL TEMPERATURE.
!   NOT A OUTPUT FROM WRF
      IF (IGET(158)>0) THEN
!$omp parallel do private(i,j)
         DO J=JSTA,JEND
           DO I=ISTA,IEND
             GRID1(I,J)=TH10(I,J)
           ENDDO
         ENDDO
         if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(158))
!$omp parallel do private(i,j,ii,jj)
            do j=1,jend-jsta+1
              jj = jsta+j-1
              do i=1,iend-ista+1
              ii = ista+i-1
                datapd(i,j,cfld) = GRID1(ii,jj)
              enddo
            enddo
         endif
       ENDIF

!        ANEMOMETER LEVEL (10 M) SENSIBLE TEMPERATURE.
!   NOT A OUTPUT FROM WRF
      IF (IGET(505)>0) THEN
!$omp parallel do private(i,j)
         DO J=JSTA,JEND
           DO I=ISTA,IEND
             GRID1(I,J)=T10M(I,J)
           ENDDO
         ENDDO
         if(grib=='grib2') then
           cfld=cfld+1
           fld_info(cfld)%ifld=IAVBLFLD(IGET(505))
!$omp parallel do private(i,j,ii,jj)
           do j=1,jend-jsta+1
             jj = jsta+j-1
             do i=1,iend-ista+1
             ii = ista+i-1
               datapd(i,j,cfld) = GRID1(ii,jj)
             enddo
           enddo
         endif
       ENDIF
!
!        ANEMOMETER LEVEL (10 M) SPECIFIC HUMIDITY.
!
      IF (IGET(159)>0) THEN
!$omp parallel do private(i,j)
         DO J=JSTA,JEND
           DO I=ISTA,IEND
             GRID1(I,J) = Q10(I,J)
           ENDDO
         ENDDO
         if(grib=='grib2') then
           cfld=cfld+1
           fld_info(cfld)%ifld=IAVBLFLD(IGET(159))
!$omp parallel do private(i,j,ii,jj)
           do j=1,jend-jsta+1
             jj = jsta+j-1
             do i=1,iend-ista+1
             ii = ista+i-1
               datapd(i,j,cfld) = GRID1(ii,jj)
             enddo
           enddo
         endif
       ENDIF
!
! SRD
!
!        ANEMOMETER LEVEL (10 M) MAX WIND SPEED.
!
      IF (IGET(422)>0) THEN
!$omp parallel do private(i,j)
         DO J=JSTA,JEND
           DO I=ISTA,IEND
             GRID1(I,J) = WSPD10MAX(I,J)
           ENDDO
         ENDDO
         if(grib=='grib2') then
           cfld=cfld+1
           fld_info(cfld)%ifld=IAVBLFLD(IGET(422))
           if (ifhr==0) then
              fld_info(cfld)%tinvstat=0
           else
              fld_info(cfld)%tinvstat=1
           endif
           fld_info(cfld)%ntrange=1
!$omp parallel do private(i,j,ii,jj)
           do j=1,jend-jsta+1
             jj = jsta+j-1
             do i=1,iend-ista+1
             ii = ista+i-1
               datapd(i,j,cfld) = GRID1(ii,jj)
             enddo
           enddo
         endif
      ENDIF

!        ANEMOMETER LEVEL (10 M) MAX WIND SPEED U COMPONENT.
!
      IF (IGET(783)>0) THEN 
!$omp parallel do private(i,j)
         DO J=JSTA,JEND
           DO I=ISTA,IEND
             GRID1(I,J) = WSPD10UMAX(I,J)
           ENDDO
         ENDDO
         if(grib=='grib2') then 
           cfld=cfld+1
           fld_info(cfld)%ifld=IAVBLFLD(IGET(783))
           if (ifhr==0) then 
              fld_info(cfld)%tinvstat=0
           else 
              fld_info(cfld)%tinvstat=1
           endif
           fld_info(cfld)%ntrange=1
!$omp parallel do private(i,j,ii,jj)
           do j=1,jend-jsta+1
             jj = jsta+j-1
             do i=1,iend-ista+1
             ii = ista+i-1
               datapd(i,j,cfld) = GRID1(ii,jj)
             enddo
           enddo
         endif
      ENDIF

!        ANEMOMETER LEVEL (10 M) MAX WIND SPEED V COMPONENT.
!
      IF (IGET(784)>0) THEN
!$omp parallel do private(i,j)
         DO J=JSTA,JEND
           DO I=ISTA,IEND
             GRID1(I,J) = WSPD10VMAX(I,J)
           ENDDO
         ENDDO
         if(grib=='grib2') then
           cfld=cfld+1
           fld_info(cfld)%ifld=IAVBLFLD(IGET(784))
           if (ifhr==0) then
              fld_info(cfld)%tinvstat=0
           else
              fld_info(cfld)%tinvstat=1
           endif
           fld_info(cfld)%ntrange=1
!$omp parallel do private(i,j,ii,jj)
           do j=1,jend-jsta+1
             jj = jsta+j-1
             do i=1,iend-ista+1
             ii = ista+i-1
               datapd(i,j,cfld) = GRID1(i,jj)
             enddo
           enddo
         endif
      ENDIF

!
! SRD
!

!       Ice Growth Rate
!
      IF (IGET(588)>0) THEN

         CALL CALVESSEL(ICEG(ista:iend,jsta:jend))

         DO J=JSTA,JEND
           DO I=ISTA,IEND
             GRID1(I,J) = ICEG(I,J)
           ENDDO
         ENDDO

         if(grib=='grib2') then
           cfld=cfld+1
           fld_info(cfld)%ifld=IAVBLFLD(IGET(588))
           if (ifhr==0) then
              fld_info(cfld)%tinvstat=0
           else
              fld_info(cfld)%tinvstat=1
           endif
           fld_info(cfld)%ntrange=1

!$omp parallel do private(i,j,ii,jj)
           do j=1,jend-jsta+1
             jj = jsta+j-1
             do i=1,iend-ista+1
             ii = ista+i-1
               datapd(i,j,cfld) = GRID1(ii,jj)
             enddo
           enddo
         endif

      ENDIF

!
!***  BLOCK 4.  PRECIPITATION RELATED FIELDS.
!MEB 6/17/02  ASSUMING THAT ALL ACCUMULATED FIELDS NEVER EMPTY
!             THEIR BUCKETS.  THIS IS THE EASIEST WAY TO DEAL WITH
!             ACCUMULATED FIELDS.  SHORTER TIME ACCUMULATIONS CAN
!             BE COMPUTED AFTER THE FACT IN A SEPARATE CODE ONCE
!             THE POST HAS FINISHED.  I HAVE LEFT IN THE OLD
!             ETAPOST CODE FOR COMPUTING THE BEGINNING TIME OF
!             THE ACCUMULATION PERIOD IF THIS IS CHANGED BACK
!             TO A 12H OR 3H BUCKET.  I AM NOT SURE WHAT
!             TO DO WITH THE TIME AVERAGED FIELDS, SO
!             LEAVING THAT UNCHANGED.
!     
!     SNOW FRACTION FROM EXPLICIT CLOUD SCHEME.  LABELLED AS
!      'PROB OF FROZEN PRECIP' IN GRIB, 
!      DIDN'T KNOW WHAT ELSE TO CALL IT
      IF (IGET(172)>0) THEN
!$omp parallel do private(i,j)
         DO J=JSTA,JEND
           DO I=ISTA,IEND
              IF (PREC(I,J) <= PTHRESH .OR. SR(I,J)==spval) THEN
                GRID1(I,J) = -50.
              ELSE
                GRID1(I,J) = SR(I,J)*100.
              ENDIF
           ENDDO
         ENDDO
         if(grib=='grib2') then
           cfld=cfld+1
           fld_info(cfld)%ifld=IAVBLFLD(IGET(172))
!$omp parallel do private(i,j,ii,jj)
           do j=1,jend-jsta+1
             jj = jsta+j-1
             do i=1,iend-ista+1
             ii = ista+i-1
               datapd(i,j,cfld) = GRID1(ii,jj)
             enddo
           enddo
         endif
      ENDIF
!
!     INSTANTANEOUS CONVECTIVE PRECIPITATION RATE.
!     SUBSTITUTE WITH CUPPT IN WRF FOR NOW
      IF (IGET(249)>0) THEN
         RDTPHS=1000./DTQ2     !--- 1000 kg/m**3, density of liquid water
!        RDTPHS=1000./(TRDLW*3600.)
         GRID1=SPVAL
!$omp parallel do private(i,j)
         DO J=JSTA,JEND
           DO I=ISTA,IEND
            if(CPRATE(I,J)/=spval) GRID1(I,J) = CPRATE(I,J)*RDTPHS
!             GRID1(I,J) = CUPPT(I,J)*RDTPHS
           ENDDO
         ENDDO
         if(grib=='grib2') then
           cfld=cfld+1
           fld_info(cfld)%ifld=IAVBLFLD(IGET(249))
!$omp parallel do private(i,j,ii,jj)
           do j=1,jend-jsta+1
             jj = jsta+j-1
             do i=1,iend-ista+1
             ii = ista+i-1
               datapd(i,j,cfld) = GRID1(ii,jj)
             enddo
           enddo
         endif
      ENDIF
!
!     INSTANTANEOUS PRECIPITATION RATE.
      IF (IGET(167)>0) THEN
!MEB need to get physics DT
         RDTPHS=1./(DTQ2) 
!MEB need to get physics DT
         GRID1=SPVAL
!$omp parallel do private(i,j)
         DO J=JSTA,JEND
           DO I=ISTA,IEND
           if(PREC(I,J)/=spval) then
             IF(MODELNAME /= 'RSM') THEN
              GRID1(I,J) = PREC(I,J)*RDTPHS*1000.
             ELSE        !Add by Binbin
              GRID1(I,J) = PREC(I,J)
             END IF
           endif
           ENDDO
         ENDDO
         if(grib=='grib2') then
           cfld=cfld+1
           fld_info(cfld)%ifld=IAVBLFLD(IGET(167))
!$omp parallel do private(i,j,ii,jj)
           do j=1,jend-jsta+1
             jj = jsta+j-1
             do i=1,iend-ista+1
             ii = ista+i-1
               datapd(i,j,cfld) = GRID1(ii,jj)
             enddo
           enddo
         endif
      ENDIF
!
! MAXIMUM INSTANTANEOUS PRECIPITATION RATE.
      IF (IGET(508)>0) THEN
         IF (IFHR==0) THEN
           ID(18) = 0
         ELSE
           ID(18) = IFHR - 1
         ENDIF
!-- PRATE_MAX in units of mm/h from NMMB history files
         GRID1=SPVAL
         DO J=JSTA,JEND
           DO I=ISTA,IEND
            if(PRATE_MAX(I,J)/=spval) GRID1(I,J)=PRATE_MAX(I,J)*SEC2HR
           ENDDO
         ENDDO
         ITSRFC = NINT(TSRFC)
         if(grib=='grib2') then
           cfld=cfld+1
           fld_info(cfld)%ifld=IAVBLFLD(IGET(508))
           fld_info(cfld)%lvl=LVLSXML(1,IGET(508))
           if(ITSRFC>0) then
             fld_info(cfld)%ntrange=1
           else
             fld_info(cfld)%ntrange=0
           endif
           fld_info(cfld)%tinvstat=IFHR-ID(18)
!$omp parallel do private(i,j,ii,jj)
           do j=1,jend-jsta+1
             jj = jsta+j-1
             do i=1,iend-ista+1
             ii = ista+i-1
               datapd(i,j,cfld) = GRID1(ii,jj)
             enddo
           enddo
         endif
      ENDIF
!
! MAXIMUM INSTANTANEOUS *FROZEN* PRECIPITATION RATE.
      IF (IGET(509)>0) THEN
!-- FPRATE_MAX in units of mm/h from NMMB history files
         GRID1=SPVAL
         DO J=JSTA,JEND
           DO I=ISTA,IEND
            if(FPRATE_MAX(I,J)/=spval) GRID1(I,J)=FPRATE_MAX(I,J)*SEC2HR
           ENDDO
         ENDDO
         if(grib=='grib2') then
           cfld=cfld+1
           fld_info(cfld)%ifld=IAVBLFLD(IGET(509))
           fld_info(cfld)%lvl=LVLSXML(1,IGET(509))
           fld_info(cfld)%tinvstat=1
           if (IFHR > 0) then
             fld_info(cfld)%ntrange=1
           else
             fld_info(cfld)%ntrange=0
           endif
!$omp parallel do private(i,j,ii,jj)
           do j=1,jend-jsta+1
             jj = jsta+j-1
             do i=1,iend-ista+1
             ii = ista+i-1
               datapd(i,j,cfld) = GRID1(ii,jj)
             enddo
           enddo
         endif
      ENDIF
!
!     TIME-AVERAGED CONVECTIVE PRECIPITATION RATE.
      IF (IGET(272)>0) THEN
         RDTPHS=1000./DTQ2     !--- 1000 kg/m**3, density of liquid water
         ID(1:25) = 0
         ITPREC     = NINT(TPREC)
!mp
	 if (ITPREC /= 0) then
          IFINCR     = MOD(IFHR,ITPREC)
	  IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITPREC*60)
	 else
	  IFINCR     = 0
	 endif
!mp
         ID(18)     = 0
         ID(19)     = IFHR
	 IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
         ID(20)     = 3
         IF (IFINCR==0) THEN
          ID(18) = IFHR-ITPREC
         ELSE
          ID(18) = IFHR-IFINCR
	  IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
         ENDIF
         IF (ID(18)<0) ID(18) = 0
	 grid1=spval
!$omp parallel do private(i,j)
         DO J=JSTA,JEND
           DO I=ISTA,IEND
             if(AVGCPRATE(I,J)/=spval) GRID1(I,J) = AVGCPRATE(I,J)*RDTPHS
           ENDDO
         ENDDO
        
!          print *,'in surf,iget(272)=',iget(272),'RDTPHS=',RDTPHS, &
!           'AVGCPRATE=',maxval(AVGCPRATE(1:im,jsta:jend)),minval(AVGCPRATE(1:im,jsta:jend)), &
!           'grid1=',maxval(grid1(1:im,jsta:jend)),minval(grid1(1:im,jsta:jend))
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(272))

            if(ITPREC==0) then
              fld_info(cfld)%ntrange=0
            else
              fld_info(cfld)%ntrange=1
            endif
            fld_info(cfld)%tinvstat=IFHR-ID(18)

!$omp parallel do private(i,j,ii,jj)
            do j=1,jend-jsta+1
              jj = jsta+j-1
              do i=1,iend-ista+1
              ii = ista+i-1
                datapd(i,j,cfld) = GRID1(ii,jj)
              enddo
            enddo
           endif
      ENDIF
!      
!     TIME-AVERAGED PRECIPITATION RATE.
      IF (IGET(271)>0) THEN
         RDTPHS=1000./DTQ2     !--- 1000 kg/m**3, density of liquid water
!         RDTPHS=1000./(TRDLW*3600.)
         ID(1:25) = 0
         ITPREC     = NINT(TPREC)
!mp
	 if (ITPREC /= 0) then
          IFINCR     = MOD(IFHR,ITPREC)
	  IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITPREC*60)
	 else
	  IFINCR     = 0
	 endif
!mp
         ID(18)     = 0
         ID(19)     = IFHR
	 IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
         ID(20)     = 3
         IF (IFINCR==0) THEN
          ID(18) = IFHR-ITPREC
         ELSE
          ID(18) = IFHR-IFINCR
          IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
         ENDIF
         IF (ID(18)<0) ID(18) = 0
         grid1=spval
!$omp parallel do private(i,j)
         DO J=JSTA,JEND
           DO I=ISTA,IEND
             if(avgprec(i,j)/=spval) GRID1(I,J) = AVGPREC(I,J)*RDTPHS
           ENDDO
         ENDDO
        
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(271))

            if(ITPREC==0) then
              fld_info(cfld)%ntrange=0
            else
              fld_info(cfld)%ntrange=1
            endif
            fld_info(cfld)%tinvstat=IFHR-ID(18)

!$omp parallel do private(i,j,ii,jj)
            do j=1,jend-jsta+1
              jj = jsta+j-1
              do i=1,iend-ista+1
              ii = ista+i-1
                datapd(i,j,cfld) = GRID1(ii,jj)
              enddo
            enddo
           endif
      ENDIF
!     
!     ACCUMULATED TOTAL PRECIPITATION.
      IF (IGET(087)>0) THEN
         ID(1:25) = 0
         ITPREC     = NINT(TPREC)
!mp
	if (ITPREC /= 0) then
         IFINCR     = MOD(IFHR,ITPREC)
	 IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITPREC*60)
	else
	 IFINCR     = 0
	endif
!mp
         ID(18)     = 0
         ID(19)     = IFHR
	 IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
         ID(20)     = 4
         IF (IFINCR==0) THEN
          ID(18) = IFHR-ITPREC
         ELSE
          ID(18) = IFHR-IFINCR
	  IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
         ENDIF
         IF(MODELNAME == 'GFS' .OR. MODELNAME == 'FV3R') THEN
!$omp parallel do private(i,j)
           DO J=JSTA,JEND
             DO I=ISTA,IEND
               IF(AVGPREC(I,J) < SPVAL)THEN
                 GRID1(I,J) = AVGPREC(I,J)*FLOAT(ID(19)-ID(18))*3600.*1000./DTQ2
               ELSE
                 GRID1(I,J) = SPVAL
               END IF 
             ENDDO
           ENDDO
!! Chuang 3/29/2018: add continuous bucket
!           DO J=JSTA,JEND
!             DO I=ISTA,IEND
!               IF(AVGPREC_CONT(I,J) < SPVAL)THEN
!                 GRID2(I,J) = AVGPREC_CONT(I,J)*FLOAT(IFHR)*3600.*1000./DTQ2
!               ELSE
!                 GRID2(I,J) = SPVAL
!               END IF
!             ENDDO
!           ENDDO
         ELSE   
!$omp parallel do private(i,j)
           DO J=JSTA,JEND
             DO I=ISTA,IEND
              IF(ACPREC(I,J) < SPVAL)THEN
               GRID1(I,J) = ACPREC(I,J)*1000.
              ELSE
               GRID1(I,J) = SPVAL
              ENDIF
             ENDDO
           ENDDO
         END IF 
!	 IF(IFMIN >= 1 .AND. ID(19) > 256)THEN
!	  IF(ITPREC==3)ID(17)=10
!	  IF(ITPREC==6)ID(17)=11
!	  IF(ITPREC==12)ID(17)=12
!	 END IF 
         IF (ID(18)<0) ID(18) = 0
!	write(6,*) 'call gribit...total precip'
         if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(087))
            fld_info(cfld)%ntrange=1
            fld_info(cfld)%tinvstat=IFHR-ID(18)
!            print*,'id(18),tinvstat in apcp= ',ID(18),fld_info(cfld)%tinvstat
!$omp parallel do private(i,j,ii,jj)
            do j=1,jend-jsta+1
              jj = jsta+j-1
              do i=1,iend-ista+1
              ii = ista+i-1
                datapd(i,j,cfld) = GRID1(ii,jj)
              enddo
            enddo
!! add continuous bucket
!            if(MODELNAME == 'GFS' .OR. MODELNAME == 'FV3R') then
!            cfld=cfld+1
!            fld_info(cfld)%ifld=IAVBLFLD(IGET(087))
!            fld_info(cfld)%ntrange=1
!            fld_info(cfld)%tinvstat=IFHR
!            print*,'tinvstat in cont bucket= ',fld_info(cfld)%tinvstat
!              do j=1,jend-jsta+1
!                jj = jsta+j-1
!                do i=1,im
!                  datapd(i,j,cfld) = GRID2(i,jj)
!                enddo
!              enddo
!            endif
         endif
      ENDIF

!
!     CONTINOUS ACCUMULATED TOTAL PRECIPITATION.
      IF (IGET(417)>0) THEN
         ID(1:25) = 0
         ITPREC     = NINT(TPREC)
!mp
        if (ITPREC /= 0) then
         IFINCR     = MOD(IFHR,ITPREC)
         IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITPREC*60)
        else
         IFINCR     = 0
        endif
!mp
         ID(18)     = 0
         ID(19)     = IFHR
         IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
         ID(20)     = 4
         IF (IFINCR==0) THEN
          ID(18) = IFHR-ITPREC
         ELSE
          ID(18) = IFHR-IFINCR
          IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
         ENDIF
         IF(MODELNAME == 'GFS' .OR. MODELNAME == 'FV3R') THEN
! Chuang 3/29/2018: add continuous bucket
!$omp parallel do private(i,j)
           DO J=JSTA,JEND
             DO I=ISTA,IEND
               IF(AVGPREC_CONT(I,J) < SPVAL)THEN
                 GRID2(I,J) = AVGPREC_CONT(I,J)*FLOAT(IFHR)*3600.*1000./DTQ2
               ELSE
                 GRID2(I,J) = SPVAL
               END IF
             ENDDO
           ENDDO
         ENDIF
         IF (ID(18)<0) ID(18) = 0
         if(grib=='grib2') then
! add continuous bucket
            if(MODELNAME == 'GFS' .OR. MODELNAME == 'FV3R') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(417))
            fld_info(cfld)%ntrange=1
            fld_info(cfld)%tinvstat=IFHR
!            print*,'tinvstat in cont bucket= ',fld_info(cfld)%tinvstat
!$omp parallel do private(i,j,ii,jj)
              do j=1,jend-jsta+1
                jj = jsta+j-1
                do i=1,iend-ista+1
                ii = ista+i-1
                  datapd(i,j,cfld) = GRID2(ii,jj)
                enddo
              enddo
            endif
         endif
      ENDIF
!     
!     ACCUMULATED CONVECTIVE PRECIPITATION.
      IF (IGET(033)>0) THEN
         ID(1:25) = 0
         ITPREC     = NINT(TPREC)
!mp
	if (ITPREC /= 0) then
         IFINCR     = MOD(IFHR,ITPREC)
         IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITPREC*60)
	else
	 IFINCR     = 0
	endif
!mp
         ID(18)     = 0
         ID(19)     = IFHR
	 IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
         ID(20)     = 4
         IF (IFINCR==0) THEN
          ID(18) = IFHR-ITPREC
         ELSE
          ID(18) = IFHR-IFINCR
          IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
         ENDIF
         IF (ID(18)<0) ID(18) = 0
         IF(MODELNAME == 'GFS' .OR. MODELNAME == 'FV3R') THEN
!$omp parallel do private(i,j)
           DO J=JSTA,JEND
             DO I=ISTA,IEND
               IF(AVGCPRATE(I,J) < SPVAL)THEN
                 GRID1(I,J) = AVGCPRATE(I,J)*                      &
                              FLOAT(ID(19)-ID(18))*3600.*1000./DTQ2
               ELSE
                 GRID1(I,J) = SPVAL
               END IF
             ENDDO
           ENDDO
!! Chuang 3/29/2018: add continuous bucket
!           DO J=JSTA,JEND
!             DO I=ISTA,IEND
!               IF(AVGCPRATE_CONT(I,J) < SPVAL)THEN
!                 GRID2(I,J) = AVGCPRATE_CONT(I,J)*FLOAT(IFHR)*3600.*1000./DTQ2
!               ELSE
!                 GRID2(I,J) = SPVAL
!               END IF
!             ENDDO
!           ENDDO
         ELSE
!$omp parallel do private(i,j)
           DO J=JSTA,JEND
            DO I=ISTA,IEND
            IF(CUPREC(I,J) < SPVAL)THEN
             GRID1(I,J) = CUPREC(I,J)*1000.
            ELSE
             GRID1(I,J) = SPVAL
            ENDIF
            ENDDO
           ENDDO
         END IF 
!	write(6,*) 'call gribit...convective precip'
         if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(033))
            fld_info(cfld)%ntrange=1
            fld_info(cfld)%tinvstat=IFHR-ID(18)
!$omp parallel do private(i,j,ii,jj)
            do j=1,jend-jsta+1
              jj = jsta+j-1
              do i=1,iend-ista+1
              ii = ista+i-1
                datapd(i,j,cfld) = GRID1(ii,jj)
              enddo
            enddo
!! add continuous bucket
!            if(MODELNAME == 'GFS' .OR. MODELNAME == 'FV3R') then
!            cfld=cfld+1
!            fld_info(cfld)%ifld=IAVBLFLD(IGET(033))
!            fld_info(cfld)%ntrange=1
!            fld_info(cfld)%tinvstat=IFHR
!              do j=1,jend-jsta+1
!                jj = jsta+j-1
!                do i=1,im
!                  datapd(i,j,cfld) = GRID2(i,jj)
!                enddo
!              enddo
!            endif
         endif
      ENDIF

!     CONTINOUS ACCUMULATED CONVECTIVE PRECIPITATION.
      IF (IGET(418)>0) THEN
         ID(1:25) = 0
         ITPREC     = NINT(TPREC)
!mp
        if (ITPREC /= 0) then
         IFINCR     = MOD(IFHR,ITPREC)
         IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITPREC*60)
        else
         IFINCR     = 0
        endif
!mp
         ID(18)     = 0
         ID(19)     = IFHR
         IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
         ID(20)     = 4
         IF (IFINCR==0) THEN
          ID(18) = IFHR-ITPREC
         ELSE
          ID(18) = IFHR-IFINCR
          IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
         ENDIF
         IF (ID(18)<0) ID(18) = 0
         IF(MODELNAME == 'GFS' .OR. MODELNAME == 'FV3R') THEN
! Chuang 3/29/2018: add continuous bucket
!$omp parallel do private(i,j)
           DO J=JSTA,JEND
             DO I=ISTA,IEND
               IF(AVGCPRATE_CONT(I,J) < SPVAL)THEN
                 GRID2(I,J) = AVGCPRATE_CONT(I,J)*FLOAT(IFHR)*3600.*1000./DTQ2
               ELSE
                 GRID2(I,J) = SPVAL
               END IF
             ENDDO
           ENDDO
         ENDIF
!       write(6,*) 'call gribit...convective precip'
         if(grib=='grib2') then
! add continuous bucket
            if(MODELNAME == 'GFS' .OR. MODELNAME == 'FV3R') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(418))
            fld_info(cfld)%ntrange=1
            fld_info(cfld)%tinvstat=IFHR
!$omp parallel do private(i,j,ii,jj)
              do j=1,jend-jsta+1
                jj = jsta+j-1
                do i=1,iend-ista+1
                ii = ista+i-1
                  datapd(i,j,cfld) = GRID2(ii,jj)
                enddo
              enddo
            endif
         endif
      ENDIF
!     
!     ACCUMULATED GRID-SCALE PRECIPITATION.
      IF (IGET(034)>0) THEN
            
         ID(1:25) = 0
         ITPREC     = NINT(TPREC)
!mp
	if (ITPREC /= 0) then
         IFINCR     = MOD(IFHR,ITPREC)
         IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITPREC*60)
	else
	 IFINCR     = 0
	endif
!mp
         ID(18)     = 0
         ID(19)     = IFHR
	 IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
         ID(20)     = 4
         IF (IFINCR==0) THEN
          ID(18) = IFHR-ITPREC
         ELSE
          ID(18) = IFHR-IFINCR
          IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
         ENDIF
         IF (ID(18)<0) ID(18) = 0
         IF(MODELNAME == 'GFS' .OR. MODELNAME == 'FV3R') THEN
!$omp parallel do private(i,j)
           DO J=JSTA,JEND
             DO I=ISTA,IEND
               IF(AVGCPRATE(I,J) < SPVAL .AND. AVGPREC(I,J) < SPVAL) then
                 GRID1(I,J) = ( AVGPREC(I,J) - AVGCPRATE(I,J) ) *          &
                                FLOAT(ID(19)-ID(18))*3600.*1000./DTQ2
               ELSE
                 GRID1(I,J) = SPVAL
               END IF 
             ENDDO
           ENDDO
!! Chuang 3/29/2018: add continuous bucket
!           DO J=JSTA,JEND
!             DO I=ISTA,IEND
!               IF(AVGCPRATE_CONT(I,J) < SPVAL .AND. AVGPREC_CONT(I,J) < SPVAL)THEN
!                 GRID2(I,J) = (AVGPREC_CONT(I,J) - AVGCPRATE_CONT(I,J)) &
!                 *FLOAT(IFHR)*3600.*1000./DTQ2
!               ELSE
!                 GRID2(I,J) = SPVAL
!               END IF
!             ENDDO
!           ENDDO
         ELSE
!$omp parallel do private(i,j)
           DO J=JSTA,JEND
             DO I=ISTA,IEND
               GRID1(I,J) = ANCPRC(I,J)*1000.
             ENDDO
            ENDDO
         END IF  
!	write(6,*) 'call gribit...grid-scale precip'
         if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(034))
            fld_info(cfld)%ntrange=1
            fld_info(cfld)%tinvstat=IFHR-ID(18)
!$omp parallel do private(i,j,ii,jj)
            do j=1,jend-jsta+1
              jj = jsta+j-1
              do i=1,iend-ista+1
              ii = ista+i-1
                datapd(i,j,cfld) = GRID1(ii,jj)
              enddo
            enddo
!! add continuous bucket
!            if(MODELNAME == 'GFS' .OR. MODELNAME == 'FV3R') then
!            cfld=cfld+1
!            fld_info(cfld)%ifld=IAVBLFLD(IGET(034))
!            fld_info(cfld)%ntrange=1
!            fld_info(cfld)%tinvstat=IFHR
!              do j=1,jend-jsta+1
!                jj = jsta+j-1
!                do i=1,iend-ista+1
!                ii = ista+1-1
!                  datapd(i,j,cfld) = GRID2(ii,jj)
!                enddo
!              enddo
!            endif
         endif
      ENDIF

!     CONTINOUS ACCUMULATED GRID-SCALE PRECIPITATION.
      IF (IGET(419)>0) THEN
         ID(1:25) = 0
         ITPREC     = NINT(TPREC)
!mp
        if (ITPREC /= 0) then
         IFINCR     = MOD(IFHR,ITPREC)
         IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITPREC*60)
        else
         IFINCR     = 0
        endif
!mp
         ID(18)     = 0
         ID(19)     = IFHR
         IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
         ID(20)     = 4
         IF (IFINCR==0) THEN
          ID(18) = IFHR-ITPREC
         ELSE
          ID(18) = IFHR-IFINCR
          IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
         ENDIF
         IF (ID(18)<0) ID(18) = 0
         IF(MODELNAME == 'GFS' .OR. MODELNAME == 'FV3R') THEN
! Chuang 3/29/2018: add continuous bucket
!$omp parallel do private(i,j)
           DO J=JSTA,JEND
             DO I=ISTA,IEND
               IF(AVGCPRATE_CONT(I,J) < SPVAL .AND. AVGPREC_CONT(I,J) < SPVAL)THEN
                 GRID2(I,J) = (AVGPREC_CONT(I,J) - AVGCPRATE_CONT(I,J)) &
                 *FLOAT(IFHR)*3600.*1000./DTQ2
               ELSE
                 GRID2(I,J) = SPVAL
               END IF
             ENDDO
           ENDDO
         ENDIF
!       write(6,*) 'call gribit...grid-scale precip'
         if(grib=='grib2') then
! add continuous bucket
            if(MODELNAME == 'GFS' .OR. MODELNAME == 'FV3R') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(419))
            fld_info(cfld)%ntrange=1
            fld_info(cfld)%tinvstat=IFHR
!$omp parallel do private(i,j,ii,jj)
              do j=1,jend-jsta+1
                jj = jsta+j-1
                do i=1,iend-ista+1
                ii = ista+i-1
                  datapd(i,j,cfld) = GRID2(ii,jj)
                enddo
              enddo
            endif
         endif
      ENDIF
!     
!     ACCUMULATED LAND SURFACE PRECIPITATION.
      IF (IGET(256)>0) THEN
      GRID1=SPVAL
!$omp parallel do private(i,j)
         DO J=JSTA,JEND
           DO I=ISTA,IEND
            IF(LSPA(I,J)<=-1.0E-6)THEN
             if(ACPREC(I,J)/=spval) GRID1(I,J) = ACPREC(I,J)*1000
            ELSE
             if(LSPA(I,J)/=spval) GRID1(I,J) = LSPA(I,J)*1000.
            END IF
           ENDDO
         ENDDO
         ID(1:25) = 0
         ITPREC     = NINT(TPREC)
!mp
	if (ITPREC /= 0) then
         IFINCR     = MOD(IFHR,ITPREC)
         IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITPREC*60)
	else
	 IFINCR     = 0
	endif
!mp
         ID(18)     = 0
         ID(19)     = IFHR
         IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
         ID(20)     = 4
         IF (IFINCR==0) THEN
          ID(18) = IFHR-ITPREC
         ELSE
          ID(18) = IFHR-IFINCR
          IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
         ENDIF
         IF (ID(18)<0) ID(18) = 0
         ID(02)= 130
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(256))
            fld_info(cfld)%ntrange=1
            fld_info(cfld)%tinvstat=IFHR-ID(18)
!$omp parallel do private(i,j,ii,jj)
            do j=1,jend-jsta+1
              jj = jsta+j-1
              do i=1,iend-ista+1
              ii = ista+i-1
                datapd(i,j,cfld) = GRID1(ii,jj)
              enddo
            enddo
           endif
      ENDIF
!     
!     ACCUMULATED SNOWFALL.
      IF (IGET(035)>0) THEN
!$omp parallel do private(i,j)
         DO J=JSTA,JEND
           DO I=ISTA,IEND
!            GRID1(I,J) = ACSNOW(I,J)*1000.
             GRID1(I,J) = ACSNOW(I,J)
           ENDDO
         ENDDO
         ID(1:25) = 0
         ITPREC     = NINT(TPREC)
!mp
         if (ITPREC /= 0) then
           IFINCR     = MOD(IFHR,ITPREC)
           IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITPREC*60)
         else
           IFINCR     = 0
         endif
!mp
         ID(18)     = 0
         ID(19)     = IFHR
         IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
         ID(20)     = 4
         IF (IFINCR==0) THEN
           ID(18) = IFHR-ITPREC
         ELSE
           ID(18) = IFHR-IFINCR
           IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
         ENDIF
         IF (ID(18)<0) ID(18) = 0
        if(grib=='grib2') then
          cfld=cfld+1
           fld_info(cfld)%ifld=IAVBLFLD(IGET(035))
           fld_info(cfld)%ntrange=1
          fld_info(cfld)%tinvstat=IFHR
!$omp parallel do private(i,j,ii,jj)
          do j=1,jend-jsta+1
            jj = jsta+j-1
            do i=1,iend-ista+1
            ii = ista+i-1
              datapd(i,j,cfld) = GRID1(ii,jj)
            enddo
          enddo
        endif
      ENDIF
!     
!     ACCUMULATED GRAUPEL.
         IF (IGET(746)>0) THEN 
!$omp parallel do private(i,j)
            DO J=JSTA,JEND
              DO I=ISTA,IEND
                GRID1(I,J) = ACGRAUP(I,J)
              ENDDO
            ENDDO
            ID(1:25) = 0
            ITPREC     = NINT(TPREC)
!mp
        if (ITPREC /= 0) then 
         IFINCR     = MOD(IFHR,ITPREC)
         IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITPREC*60)
        else
         IFINCR     = 0  
        endif
!mp
            ID(18)     = 0  
            ID(19)     = IFHR 
            IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
            ID(20)     = 4  
            IF (IFINCR==0) THEN 
             ID(18) = IFHR-ITPREC
            ELSE 
             ID(18) = IFHR-IFINCR
             IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
            ENDIF
            IF (ID(18)<0) ID(18) = 0
           if(grib=='grib2') then 
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(746))
            fld_info(cfld)%ntrange=1
            fld_info(cfld)%tinvstat=IFHR-ID(18)
            if(MODELNAME=='FV3R' .OR. MODELNAME=='GFS')fld_info(cfld)%tinvstat=IFHR
!$omp parallel do private(i,j,ii,jj)
            do j=1,jend-jsta+1
              jj = jsta+j-1
              do i=1,iend-ista+1
              ii = ista+i-1
                datapd(i,j,cfld) = GRID1(ii,jj)
              enddo
            enddo
           endif
         ENDIF
!     
!     ACCUMULATED FREEZING RAIN.
         IF (IGET(782)>0) THEN 
!$omp parallel do private(i,j)
            DO J=JSTA,JEND
              DO I=ISTA,IEND
                GRID1(I,J) = ACFRAIN(I,J)
              ENDDO
            ENDDO
            ID(1:25) = 0
            ITPREC     = NINT(TPREC)
!mp
        if (ITPREC /= 0) then 
         IFINCR     = MOD(IFHR,ITPREC)
         IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITPREC*60)
        else 
         IFINCR     = 0  
        endif
!mp
            ID(18)     = 0  
            ID(19)     = IFHR 
            IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
            ID(20)     = 4  
            IF (IFINCR==0) THEN 
             ID(18) = IFHR-ITPREC
            ELSE 
             ID(18) = IFHR-IFINCR
             IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
            ENDIF
            IF (ID(18)<0) ID(18) = 0
           if(grib=='grib2') then 
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(782))
            fld_info(cfld)%ntrange=1
            fld_info(cfld)%tinvstat=IFHR-ID(18)
            if(MODELNAME=='FV3R' .OR. MODELNAME=='GFS')fld_info(cfld)%tinvstat=IFHR
!$omp parallel do private(i,j,ii,jj)
            do j=1,jend-jsta+1
              jj = jsta+j-1
              do i=1,iend-ista+1
              ii = ista+i-1
                datapd(i,j,cfld) = GRID1(ii,jj)
              enddo
            enddo
           endif
         ENDIF

!     ACCUMULATED SNOWFALL.
         IF (IGET(1004)>0) THEN
!$omp parallel do private(i,j)
            DO J=JSTA,JEND
              DO I=ISTA,IEND
                GRID1(I,J) = SNOW_ACM(I,J)
              ENDDO
            ENDDO
            ID(1:25) = 0
            ITPREC     = NINT(TPREC)
!mp
        if (ITPREC /= 0) then
         IFINCR     = MOD(IFHR,ITPREC)
         IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITPREC*60)
        else
         IFINCR     = 0
        endif
!mp
            ID(18)     = 0
            ID(19)     = IFHR
            IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
            ID(20)     = 4
            IF (IFINCR==0) THEN
             ID(18) = IFHR-ITPREC
            ELSE
             ID(18) = IFHR-IFINCR
             IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
            ENDIF
            IF (ID(18)<0) ID(18) = 0
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(1004))
            fld_info(cfld)%ntrange=1
            fld_info(cfld)%tinvstat=IFHR-ID(18)
            if(MODELNAME=='FV3R' .or. MODELNAME=='GFS')fld_info(cfld)%tinvstat=IFHR
!            print*,'id(18),tinvstat in acgraup= ',ID(18),fld_info(cfld)%tinvstat
!$omp parallel do private(i,j,ii,jj)
            do j=1,jend-jsta+1
              jj = jsta+j-1
              do i=1,iend-ista+1
              ii = ista+i-1
                datapd(i,j,cfld) = GRID1(ii,jj)
              enddo
            enddo
           endif
         ENDIF

!     
!     ACCUMULATED SNOW MELT.
      IF (IGET(121)>0) THEN
!$omp parallel do private(i,j)
         DO J=JSTA,JEND
           DO I=ISTA,IEND
!            GRID1(I,J) = ACSNOM(I,J)*1000.
             GRID1(I,J) = ACSNOM(I,J)     
           ENDDO
         ENDDO
         ID(1:25) = 0
         ITPREC     = NINT(TPREC)
!mp
         if (ITPREC /= 0) then
           IFINCR     = MOD(IFHR,ITPREC)
           IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITPREC*60)
         else
           IFINCR     = 0
         endif
!mp
         ID(18)     = 0
         ID(19)     = IFHR
         IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
           ID(20)     = 4
           IF (IFINCR==0) THEN
             ID(18) = IFHR-ITPREC
           ELSE
             ID(18) = IFHR-IFINCR
             IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
           ENDIF
           IF (ID(18)<0) ID(18) = 0
           if(grib=='grib2') then
             cfld=cfld+1
             fld_info(cfld)%ifld=IAVBLFLD(IGET(121))
             fld_info(cfld)%ntrange=1
             fld_info(cfld)%tinvstat=IFHR-ID(18)
!$omp parallel do private(i,j,ii,jj)
             do j=1,jend-jsta+1
               jj = jsta+j-1
               do i=1,iend-ista+1
               ii = ista+i-1
                 datapd(i,j,cfld) = GRID1(ii,jj)
               enddo
             enddo
           endif
         ENDIF
!
!     ACCUMULATED SNOWFALL RATE
         IF (IGET(405)>0) THEN
!$omp parallel do private(i,j)
           DO J=JSTA,JEND
             DO I=ISTA,IEND
               GRID1(I,J) = SNOWFALL(I,J)
             ENDDO
           ENDDO
           ID(1:25) = 0
           ITPREC     = NINT(TPREC)
!mp
           if (ITPREC /= 0) then
             IFINCR     = MOD(IFHR,ITPREC)
             IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITPREC*60)
           else
             IFINCR     = 0
           endif
!mp
           ID(18)     = 0
           ID(19)     = IFHR
           IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
           ID(20)     = 4
           IF (IFINCR==0) THEN
             ID(18) = IFHR-ITPREC
           ELSE
             ID(18) = IFHR-IFINCR
             IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
           ENDIF
           IF (ID(18)<0) ID(18) = 0
           IF(ITPREC < 0)ID(1:25)=0
           if(grib=='grib2') then
             cfld=cfld+1
             fld_info(cfld)%ifld=IAVBLFLD(IGET(405))
             fld_info(cfld)%ntrange=1
             fld_info(cfld)%tinvstat=IFHR-ID(18)
!$omp parallel do private(i,j,ii,jj)
             do j=1,jend-jsta+1
               jj = jsta+j-1
               do i=1,iend-ista+1
               ii = ista+i-1
                 datapd(i,j,cfld) = GRID1(ii,jj)
               enddo
             enddo
           endif
         ENDIF
!     
!     ACCUMULATED STORM SURFACE RUNOFF.
         IF (IGET(122)>0) THEN
!$omp parallel do private(i,j)
           DO J=JSTA,JEND
             DO I=ISTA,IEND
!              GRID1(I,J) = SSROFF(I,J)*1000.
               GRID1(I,J) = SSROFF(I,J)
             ENDDO
           ENDDO
           ID(1:25) = 0
           ITPREC     = NINT(TPREC)
!mp
           if (ITPREC /= 0) then
             IFINCR     = MOD(IFHR,ITPREC)
             IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITPREC*60)
           else
             IFINCR     = 0
           endif
!mp
           ID(18)     = 0
           ID(19)     = IFHR
           IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
           ID(20)     = 4
           IF (IFINCR==0) THEN
             ID(18) = IFHR-ITPREC
           ELSE
             ID(18) = IFHR-IFINCR
             IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
           ENDIF
           IF (ID(18)<0) ID(18) = 0
!    1-HR RUNOFF ACCUMULATIONS IN RR
           IF (MODELNAME=='RAPR')  THEN
             IF (IFHR > 0) THEN
               ID(18)=IFHR-1
             ELSE
               ID(18)=0
             ENDIF
           ENDIF
           if(grib=='grib2') then
             cfld=cfld+1
             fld_info(cfld)%ifld=IAVBLFLD(IGET(122))
             fld_info(cfld)%ntrange=1
             fld_info(cfld)%tinvstat=IFHR-ID(18)
!$omp parallel do private(i,j,ii,jj)
             do j=1,jend-jsta+1
               jj = jsta+j-1
               do i=1,iend-ista+1
               ii = ista+i-1
                 datapd(i,j,cfld) = GRID1(ii,jj)
               enddo
             enddo
           endif
         ENDIF
!     
!     ACCUMULATED BASEFLOW-GROUNDWATER RUNOFF.
         IF (IGET(123)>0) THEN
!$omp parallel do private(i,j)
           DO J=JSTA,JEND
             DO I=ISTA,IEND
!              GRID1(I,J) = BGROFF(I,J)*1000.
               GRID1(I,J) = BGROFF(I,J)
             ENDDO
           ENDDO
           ID(1:25) = 0
           ITPREC     = NINT(TPREC)
!mp
           if (ITPREC /= 0) then
             IFINCR     = MOD(IFHR,ITPREC)
             IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITPREC*60)
           else
             IFINCR     = 0
           endif
!mp
           ID(18)     = IFHR - 1 
           ID(19)     = IFHR
           IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
           ID(20)     = 4
           IF (IFINCR==0) THEN
             ID(18) = IFHR-ITPREC
           ELSE
             ID(18) = IFHR-IFINCR
             IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
           ENDIF
           IF (ID(18)<0) ID(18) = 0
!    1-HR RUNOFF ACCUMULATIONS IN RR
           IF (MODELNAME=='RAPR')  THEN
             IF (IFHR > 0) THEN
               ID(18)=IFHR-1
             ELSE
               ID(18)=0
             ENDIF
           ENDIF
           if(grib=='grib2') then
             cfld=cfld+1
             fld_info(cfld)%ifld=IAVBLFLD(IGET(123))
             fld_info(cfld)%ntrange=1
             fld_info(cfld)%tinvstat=IFHR-ID(18)
!$omp parallel do private(i,j,ii,jj)
             do j=1,jend-jsta+1
               jj = jsta+j-1
               do i=1,iend-ista+1
               ii = ista+i-1
                 datapd(i,j,cfld) = GRID1(ii,jj)
               enddo
             enddo
           endif
         ENDIF
!     
!     ACCUMULATED WATER RUNOFF.
         IF (IGET(343)>0) THEN
!$omp parallel do private(i,j)
           DO J=JSTA,JEND
             DO I=ISTA,IEND
               GRID1(I,J) = RUNOFF(I,J)
             ENDDO
           ENDDO
           ID(1:25) = 0
           ITPREC     = NINT(TPREC)
! GFS starts to use continuous bucket for precipitation only
! so have to change water runoff to use different bucket
           if(MODELNAME == 'GFS')ITPREC=NINT(tmaxmin)
!mp
           if (ITPREC /= 0) then
             IFINCR     = MOD(IFHR,ITPREC)
             IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITPREC*60)
           else
             IFINCR     = 0
           endif
!mp
           ID(18)     = 0
           ID(19)     = IFHR
           IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
           ID(20)     = 4
           IF (IFINCR==0) THEN
             ID(18) = IFHR-ITPREC
           ELSE
             ID(18) = IFHR-IFINCR
             IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
           ENDIF
           IF (ID(18)<0) ID(18) = 0
           if(grib=='grib2') then
             cfld=cfld+1
             fld_info(cfld)%ifld=IAVBLFLD(IGET(343))
             fld_info(cfld)%ntrange=1
             fld_info(cfld)%tinvstat=IFHR-ID(18)
!$omp parallel do private(i,j,ii,jj)
             do j=1,jend-jsta+1
               jj = jsta+j-1
               do i=1,iend-ista+1
               ii = ista+i-1
                 datapd(i,j,cfld) = GRID1(ii,jj)
               enddo
             enddo
           endif
         ENDIF

!     PRECIPITATION BUCKETS - accumulated between output times
!     'BUCKET TOTAL PRECIP '
         NEED_IFI = IGET(1007)>0 .or. IGET(1008)>0 .or. IGET(1009)>0 .or. IGET(1010)>0
         IF (IGET(434)>0. .or. NEED_IFI) THEN
!$omp parallel do private(i,j)
           DO J=JSTA,JEND
             DO I=ISTA,IEND
               IF (IFHR == 0) THEN
                 IFI_APCP(I,J) = 0.0
               ELSE
                 IFI_APCP(I,J) = PCP_BUCKET(I,J)
               ENDIF 
             ENDDO
           ENDDO
           ! Note: IFI.F may replace IFI_APCP with other values where it is spval or 0
         ENDIF

         IF (IGET(434)>0.) THEN
           ID(1:25) = 0
           ITPREC     = NINT(TPREC)
!mp
           if (ITPREC /= 0) then
             IFINCR     = MOD(IFHR,ITPREC)
             IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITPREC*60)
           else
             IFINCR     = 0
           endif
!mp
           if(MODELNAME=='NCAR' .OR. MODELNAME=='RAPR') IFINCR = NINT(PREC_ACC_DT)/60
           ID(18)     = 0
           ID(19)     = IFHR
           IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
           ID(20)     = 4
           IF (IFINCR==0) THEN
             ID(18) = IFHR-ITPREC
           ELSE
             ID(18) = IFHR-IFINCR
             IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
           ENDIF
           IF (ID(18)<0) ID(18) = 0
           if(grib=='grib2' .and. IGET(434)>0) then
             cfld=cfld+1
             fld_info(cfld)%ifld=IAVBLFLD(IGET(434))
             if(ITPREC>0) then
               fld_info(cfld)%ntrange=(IFHR-ID(18))/ITPREC
             else
               fld_info(cfld)%ntrange=0
             endif
             fld_info(cfld)%tinvstat=ITPREC
             if(fld_info(cfld)%ntrange==0) then
               if (ifhr==0) then
                 fld_info(cfld)%tinvstat=0
               else
                 fld_info(cfld)%tinvstat=1
               endif
               fld_info(cfld)%ntrange=1
             end if
!$omp parallel do private(i,j,ii,jj)
             do j=1,jend-jsta+1
               jj = jsta+j-1
               do i=1,iend-ista+1
               ii = ista+i-1
                 datapd(i,j,cfld) = IFI_APCP(ii,jj)
               enddo
             enddo
           endif
         ENDIF

!     PRECIPITATION BUCKETS - accumulated between output times
!     'BUCKET CONV PRECIP  '
         IF (IGET(435)>0.) THEN
!$omp parallel do private(i,j)
           DO J=JSTA,JEND
             DO I=ISTA,IEND
               IF (IFHR == 0) THEN
                 GRID1(I,J) = 0.0
               ELSE
                 GRID1(I,J) = RAINC_BUCKET(I,J)
               ENDIF
             ENDDO
           ENDDO
           ID(1:25) = 0
           ITPREC     = NINT(TPREC)
!mp
           if (ITPREC /= 0) then
             IFINCR     = MOD(IFHR,ITPREC)
             IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITPREC*60)
           else
             IFINCR     = 0
           endif

           if(MODELNAME=='NCAR' .OR. MODELNAME=='RAPR') IFINCR = NINT(PREC_ACC_DT)/60
!mp
           ID(18)     = 0
           ID(19)     = IFHR
           IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
           ID(20)     = 4
           IF (IFINCR==0) THEN
             ID(18) = IFHR-ITPREC
           ELSE
             ID(18) = IFHR-IFINCR
             IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
           ENDIF
           IF (ID(18)<0) ID(18) = 0

!          print *,'IFMIN,IFHR,ITPREC',IFMIN,IFHR,ITPREC
           if(debugprint .and. me==0)then
             print *,'PREC_ACC_DT,ID(18),ID(19)',PREC_ACC_DT,ID(18),ID(19)
           endif

           if(grib=='grib2') then
             cfld=cfld+1
             fld_info(cfld)%ifld=IAVBLFLD(IGET(435))
             if(ITPREC>0) then
               fld_info(cfld)%ntrange=(IFHR-ID(18))/ITPREC
             else
               fld_info(cfld)%ntrange=0
             endif
             fld_info(cfld)%tinvstat=ITPREC
              if(fld_info(cfld)%ntrange==0) then 
                if (ifhr==0) then 
                  fld_info(cfld)%tinvstat=0
                else 
                  fld_info(cfld)%tinvstat=1
                endif
                fld_info(cfld)%ntrange=1
              end if
!$omp parallel do private(i,j,ii,jj)
             do j=1,jend-jsta+1
               jj = jsta+j-1
               do i=1,iend-ista+1
               ii = ista+i-1
                 datapd(i,j,cfld) = GRID1(ii,jj)
               enddo
             enddo
           endif
         ENDIF
!     PRECIPITATION BUCKETS - accumulated between output times
!     'BUCKET GRDSCALE PRCP'
         IF (IGET(436)>0.) THEN
!$omp parallel do private(i,j)
           DO J=JSTA,JEND
             DO I=ISTA,IEND
               IF (IFHR == 0) THEN
                 GRID1(I,J) = 0.0
               ELSE
                 GRID1(I,J) = RAINNC_BUCKET(I,J)
               ENDIF
             ENDDO
           ENDDO
           ID(1:25) = 0
           ITPREC     = NINT(TPREC)
!mp
           if (ITPREC /= 0) then
             IFINCR     = MOD(IFHR,ITPREC)
             IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITPREC*60)
           else
             IFINCR     = 0
           endif
!mp
           if(MODELNAME=='NCAR' .OR. MODELNAME=='RAPR') IFINCR = NINT(PREC_ACC_DT)/60
           ID(18)     = 0
           ID(19)     = IFHR
           IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
           ID(20)     = 4
           IF (IFINCR==0) THEN
             ID(18) = IFHR-ITPREC
           ELSE
             ID(18) = IFHR-IFINCR
             IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
           ENDIF
           IF (ID(18)<0) ID(18) = 0
           if(grib=='grib2') then
             cfld=cfld+1
             fld_info(cfld)%ifld=IAVBLFLD(IGET(436))
             if(ITPREC>0) then
                fld_info(cfld)%ntrange=(IFHR-ID(18))/ITPREC
             else
                fld_info(cfld)%ntrange=0
             endif
             fld_info(cfld)%tinvstat=ITPREC
              if(fld_info(cfld)%ntrange==0) then 
                if (ifhr==0) then 
                  fld_info(cfld)%tinvstat=0
                else 
                  fld_info(cfld)%tinvstat=1
                endif
                fld_info(cfld)%ntrange=1
              end if
!$omp parallel do private(i,j,ii,jj)
             do j=1,jend-jsta+1
               jj = jsta+j-1
               do i=1,iend-ista+1
               ii = ista+i-1
                 datapd(i,j,cfld) = GRID1(ii,jj)
               enddo
             enddo
           endif
         ENDIF
!     PRECIPITATION BUCKETS - accumulated between output times
!     'BUCKET SNOW  PRECIP '
         IF (IGET(437)>0.) THEN
!$omp parallel do private(i,j)
           DO J=JSTA,JEND
             DO I=ISTA,IEND
               GRID1(I,J) = SNOW_BUCKET(I,J)
             ENDDO
           ENDDO
           ID(1:25) = 0
           ITPREC     = NINT(TPREC)
!mp
           if (ITPREC /= 0) then
             IFINCR     = MOD(IFHR,ITPREC)
             IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITPREC*60)
           else
             IFINCR     = 0
           endif
!mp
           if(MODELNAME=='NCAR' .OR. MODELNAME=='RAPR') IFINCR = NINT(PREC_ACC_DT)/60
           ID(18)     = 0
           ID(19)     = IFHR
           IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
           ID(20)     = 4
           IF (IFINCR==0) THEN
             ID(18) = IFHR-ITPREC
           ELSE
             ID(18) = IFHR-IFINCR
             IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
           ENDIF
           IF (ID(18)<0) ID(18) = 0
!           if(me==0)print*,'maxval BUCKET SNOWFALL: ', maxval(GRID1)
           if(grib=='grib2') then
             cfld=cfld+1
             fld_info(cfld)%ifld=IAVBLFLD(IGET(437))
             if(ITPREC>0) then
               fld_info(cfld)%ntrange=(IFHR-ID(18))/ITPREC
             else
               fld_info(cfld)%ntrange=0
             endif
             fld_info(cfld)%tinvstat=ITPREC
             if(fld_info(cfld)%ntrange==0) then
               if (ifhr==0) then
                 fld_info(cfld)%tinvstat=0
               else
                 fld_info(cfld)%tinvstat=1
               endif
               fld_info(cfld)%ntrange=1
             end if
!$omp parallel do private(i,j,ii,jj)
             do j=1,jend-jsta+1
               jj = jsta+j-1
               do i=1,iend-ista+1
               ii = ista+i-1
                 datapd(i,j,cfld) = GRID1(ii,jj)
               enddo
             enddo
           endif
         ENDIF
!     PRECIPITATION BUCKETS - accumulated between output times
!     'BUCKET GRAUPEL PRECIP '
         IF (IGET(775)>0.) THEN 
!$omp parallel do private(i,j)
            DO J=JSTA,JEND
              DO I=ISTA,IEND
                GRID1(I,J) = GRAUP_BUCKET(I,J)
              ENDDO
            ENDDO
            ID(1:25) = 0
            ITPREC     = NINT(TPREC)
!mp
            if (ITPREC /= 0) then 
             IFINCR     = MOD(IFHR,ITPREC)
             IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITPREC*60)
            else 
             IFINCR     = 0  
            endif
!mp
           if(MODELNAME=='NCAR' .OR. MODELNAME=='RAPR') IFINCR = NINT(PREC_ACC_DT)/60
            ID(18)     = 0  
            ID(19)     = IFHR 
            IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
            ID(20)     = 4  
            IF (IFINCR==0) THEN 
             ID(18) = IFHR-ITPREC
            ELSE 
             ID(18) = IFHR-IFINCR
             IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
            ENDIF
            IF (ID(18)<0) ID(18) = 0
!      print*,'maxval BUCKET GRAUPEL: ', maxval(GRID1)
            if(grib=='grib2') then 
              cfld=cfld+1
              fld_info(cfld)%ifld=IAVBLFLD(IGET(775))
              if(ITPREC>0) then 
                fld_info(cfld)%ntrange=(IFHR-ID(18))/ITPREC
              else 
                fld_info(cfld)%ntrange=0
              endif
              fld_info(cfld)%tinvstat=ITPREC
              if(fld_info(cfld)%ntrange==0) then 
                if (ifhr==0) then 
                  fld_info(cfld)%tinvstat=0
                else 
                  fld_info(cfld)%tinvstat=1
                endif
                fld_info(cfld)%ntrange=1
              end if
              if(MODELNAME == 'GFS' .OR. MODELNAME == 'FV3R') then
                fld_info(cfld)%ntrange=1
                fld_info(cfld)%tinvstat=IFHR-ID(18)
              endif
!$omp parallel do private(i,j,ii,jj)
              do j=1,jend-jsta+1
                jj = jsta+j-1
                do i=1,iend-ista+1
                ii = ista+i-1
                  datapd(i,j,cfld) = GRID1(ii,jj)
                enddo
              enddo
            endif
         ENDIF

!     'BUCKET FREEZING RAIN '
         IF (IGET(1003)>0.) THEN
!$omp parallel do private(i,j)
            DO J=JSTA,JEND
              DO I=ISTA,IEND
                GRID1(I,J) = FRZRN_BUCKET(I,J)
              ENDDO
            ENDDO
            ID(1:25) = 0
            ITPREC     = NINT(TPREC)
!mp
            if (ITPREC /= 0) then
             IFINCR     = MOD(IFHR,ITPREC)
             IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITPREC*60)
            else
             IFINCR     = 0
            endif
!mp
            ID(18)     = 0
            ID(19)     = IFHR
            IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
            ID(20)     = 4
            IF (IFINCR==0) THEN
             ID(18) = IFHR-ITPREC
            ELSE
             ID(18) = IFHR-IFINCR
             IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
            ENDIF
            IF (ID(18)<0) ID(18) = 0
!      print*,'maxval BUCKET FREEZING RAIN: ', maxval(GRID1)
            if(grib=='grib2') then
              cfld=cfld+1
              fld_info(cfld)%ifld=IAVBLFLD(IGET(1003))
              fld_info(cfld)%ntrange=1
              fld_info(cfld)%tinvstat=IFHR-ID(18)
!              if(ITPREC>0) then
!                fld_info(cfld)%ntrange=(IFHR-ID(18))/ITPREC
!              else
!                fld_info(cfld)%ntrange=0
!              endif
!              fld_info(cfld)%tinvstat=ITPREC
!              if(fld_info(cfld)%ntrange==0) then
!                if (ifhr==0) then
!                  fld_info(cfld)%tinvstat=0
!                else
!                  fld_info(cfld)%tinvstat=1
!                endif
!                fld_info(cfld)%ntrange=1
!              end if
!$omp parallel do private(i,j,ii,jj)
              do j=1,jend-jsta+1
                jj = jsta+j-1
                do i=1,iend-ista+1
                ii = ista+i-1
                  datapd(i,j,cfld) = GRID1(ii,jj)
                enddo
              enddo
            endif
         ENDIF

!     'BUCKET SNOWFALL '
         IF (IGET(1005)>0.) THEN
!$omp parallel do private(i,j)
            DO J=JSTA,JEND
              DO I=ISTA,IEND
                GRID1(I,J) = SNOW_BKT(I,J)
              ENDDO
            ENDDO
            ID(1:25) = 0
            ITPREC     = NINT(TPREC)
!mp
            if (ITPREC /= 0) then
             IFINCR     = MOD(IFHR,ITPREC)
             IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITPREC*60)
            else
             IFINCR     = 0
            endif
!mp
            ID(18)     = 0
            ID(19)     = IFHR
            IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
            ID(20)     = 4
            IF (IFINCR==0) THEN
             ID(18) = IFHR-ITPREC
            ELSE
             ID(18) = IFHR-IFINCR
             IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
            ENDIF
            IF (ID(18)<0) ID(18) = 0
!      print*,'maxval BUCKET FREEZING RAIN: ', maxval(GRID1)
            if(grib=='grib2') then
              cfld=cfld+1
              fld_info(cfld)%ifld=IAVBLFLD(IGET(1005))
              fld_info(cfld)%ntrange=1
              fld_info(cfld)%tinvstat=IFHR-ID(18)
!$omp parallel do private(i,j,ii,jj)
              do j=1,jend-jsta+1
                jj = jsta+j-1
                do i=1,iend-ista+1
                ii = ista+i-1
                  datapd(i,j,cfld) = GRID1(ii,jj)
                enddo
              enddo
            endif
         ENDIF


!     ERIC JAMES: 10 JUN 2021 -- adding precip comparison to FFG
!     thresholds. 913 is for 1h QPF, 914 for run total QPF.
         IF (IGET(913).GT.0) THEN
            ffgfile='ffg_01h.grib2'
            call qpf_comp(913,ffgfile,1)
         ENDIF
         IF (IGET(914).GT.0) THEN
            IF (IFHR .EQ. 1) THEN
               ffgfile='ffg_01h.grib2'
               call qpf_comp(914,ffgfile,1)
            ELSEIF (IFHR .EQ. 3) THEN
               ffgfile='ffg_03h.grib2'
               call qpf_comp(914,ffgfile,3)
            ELSEIF (IFHR .EQ. 6) THEN
               ffgfile='ffg_06h.grib2'
               call qpf_comp(914,ffgfile,6)
            ELSEIF (IFHR .EQ. 12) THEN
               ffgfile='ffg_12h.grib2'
               call qpf_comp(914,ffgfile,12)
            ELSE
               ffgfile='ffg_01h.grib2'
               call qpf_comp(914,ffgfile,0)
            ENDIF
         ENDIF

!     ERIC JAMES: 8 OCT 2021 -- adding precip comparison to ARI
!     thresholds. 915 is for 1h QPF, 916 for run total QPF.

         IF (IGET(915).GT.0) THEN
            arifile='ari2y_01h.grib2'
            call qpf_comp(915,arifile,1)
         ENDIF
         IF (IGET(916).GT.0) THEN
            IF (IFHR .EQ. 1) THEN
               arifile='ari2y_01h.grib2'
               call qpf_comp(916,arifile,1)
            ELSEIF (IFHR .EQ. 3) THEN
               arifile='ari2y_03h.grib2'
               call qpf_comp(916,arifile,3)
            ELSEIF (IFHR .EQ. 6) THEN
               arifile='ari2y_06h.grib2'
               call qpf_comp(916,arifile,6)
            ELSEIF (IFHR .EQ. 12) THEN
               arifile='ari2y_12h.grib2'
               call qpf_comp(916,arifile,12)
            ELSEIF (IFHR .EQ. 24) THEN
               arifile='ari2y_24h.grib2'
               call qpf_comp(916,arifile,24)
            ELSE
               arifile='ari2y_01h.grib2'
               call qpf_comp(916,arifile,0)
            ENDIF
         ENDIF

         IF (IGET(917).GT.0) THEN
            arifile='ari5y_01h.grib2'
            call qpf_comp(917,arifile,1)
         ENDIF
         IF (IGET(918).GT.0) THEN
            IF (IFHR .EQ. 1) THEN
               arifile='ari5y_01h.grib2'
               call qpf_comp(918,arifile,1)
            ELSEIF (IFHR .EQ. 3) THEN
               arifile='ari5y_03h.grib2'
               call qpf_comp(918,arifile,3)
            ELSEIF (IFHR .EQ. 6) THEN
               arifile='ari5y_06h.grib2'
               call qpf_comp(918,arifile,6)
            ELSEIF (IFHR .EQ. 12) THEN
               arifile='ari5y_12h.grib2'
               call qpf_comp(918,arifile,12)
            ELSEIF (IFHR .EQ. 24) THEN
               arifile='ari5y_24h.grib2'
               call qpf_comp(918,arifile,24)
            ELSE
               arifile='ari5y_01h.grib2'
               call qpf_comp(918,arifile,0)
            ENDIF
         ENDIF

         IF (IGET(919).GT.0) THEN
            arifile='ari10y_01h.grib2'
            call qpf_comp(919,arifile,1)
         ENDIF
         IF (IGET(920).GT.0) THEN
            IF (IFHR .EQ. 1) THEN
               arifile='ari10y_01h.grib2'
               call qpf_comp(920,arifile,1)
            ELSEIF (IFHR .EQ. 3) THEN
               arifile='ari10y_03h.grib2'
               call qpf_comp(920,arifile,3)
            ELSEIF (IFHR .EQ. 6) THEN
               arifile='ari10y_06h.grib2'
               call qpf_comp(920,arifile,6)
            ELSEIF (IFHR .EQ. 12) THEN
               arifile='ari10y_12h.grib2'
               call qpf_comp(920,arifile,12)
            ELSEIF (IFHR .EQ. 24) THEN
               arifile='ari10y_24h.grib2'
               call qpf_comp(920,arifile,24)
            ELSE
               arifile='ari10y_01h.grib2'
               call qpf_comp(920,arifile,0)
            ENDIF
         ENDIF

         IF (IGET(921).GT.0) THEN
            arifile='ari100y_01h.grib2'
            call qpf_comp(921,arifile,1)
         ENDIF
         IF (IGET(922).GT.0) THEN
            IF (IFHR .EQ. 1) THEN
               arifile='ari100y_01h.grib2'
               call qpf_comp(922,arifile,1)
            ELSEIF (IFHR .EQ. 3) THEN
               arifile='ari100y_03h.grib2'
               call qpf_comp(922,arifile,3)
            ELSEIF (IFHR .EQ. 6) THEN
               arifile='ari100y_06h.grib2'
               call qpf_comp(922,arifile,6)
            ELSEIF (IFHR .EQ. 12) THEN
               arifile='ari100y_12h.grib2'
               call qpf_comp(922,arifile,12)
            ELSEIF (IFHR .EQ. 24) THEN
               arifile='ari100y_24h.grib2'
               call qpf_comp(922,arifile,24)
            ELSE
               arifile='ari100y_01h.grib2'
               call qpf_comp(922,arifile,0)
            ENDIF
         ENDIF

!     ERIC JAMES: 10 APR 2019 -- adding 15min precip output for RAP/HRRR
!     PRECIPITATION BUCKETS - accumulated between output times
!     'BUCKET1 TOTAL PRECIP '
         IF (IGET(526)>0.) THEN
!$omp parallel do private(i,j)
           DO J=JSTA,JEND
             DO I=ISTA,IEND
               IF (IFHR == 0 .AND. IFMIN == 0) THEN
                 GRID1(I,J) = 0.0
               ELSE
                 GRID1(I,J) = PCP_BUCKET1(I,J)
               ENDIF
             ENDDO
           ENDDO
           IFINCR = NINT(PREC_ACC_DT1)
           if(grib=='grib2') then
             cfld=cfld+1
             fld_info(cfld)%ifld=IAVBLFLD(IGET(526))
             if(fld_info(cfld)%ntrange==0) then
               if (ifhr==0 .and. ifmin==0) then
                 fld_info(cfld)%tinvstat=0
               else
                 fld_info(cfld)%tinvstat=IFINCR
               endif
               fld_info(cfld)%ntrange=1
             end if
!$omp parallel do private(i,j,ii,jj)
             do j=1,jend-jsta+1
               jj = jsta+j-1
               do i=1,iend-ista+1
               ii = ista+i-1
                 datapd(i,j,cfld) = GRID1(ii,jj)
               enddo
             enddo
           endif
         ENDIF
!     'BUCKET1 CONV PRECIP  '
         IF (IGET(527)>0.) THEN
!$omp parallel do private(i,j)
           DO J=JSTA,JEND
             DO I=ISTA,IEND
               IF (IFHR == 0 .AND. IFMIN == 0) THEN
                 GRID1(I,J) = 0.0
               ELSE
                 GRID1(I,J) = RAINC_BUCKET1(I,J)
               ENDIF
             ENDDO
           ENDDO
           IFINCR = NINT(PREC_ACC_DT1)
           if(grib=='grib2') then
             cfld=cfld+1
             fld_info(cfld)%ifld=IAVBLFLD(IGET(527))
             if(fld_info(cfld)%ntrange==0) then
               if (ifhr==0 .and. ifmin==0) then
                 fld_info(cfld)%tinvstat=0
               else
                 fld_info(cfld)%tinvstat=IFINCR
               endif
               fld_info(cfld)%ntrange=1
             end if
!$omp parallel do private(i,j,ii,jj)
             do j=1,jend-jsta+1
               jj = jsta+j-1
               do i=1,iend-ista+1
               ii = ista+i-1
                 datapd(i,j,cfld) = GRID1(ii,jj)
               enddo
             enddo
           endif
         ENDIF
!     'BUCKET1 GRDSCALE PRCP'
         IF (IGET(528)>0.) THEN
!$omp parallel do private(i,j)
           DO J=JSTA,JEND
             DO I=ISTA,IEND
               IF (IFHR == 0 .AND. IFMIN == 0) THEN
                 GRID1(I,J) = 0.0
               ELSE
                 GRID1(I,J) = RAINNC_BUCKET1(I,J)
               ENDIF
             ENDDO
           ENDDO
           IFINCR = NINT(PREC_ACC_DT1)
           if(grib=='grib2') then
             cfld=cfld+1
             fld_info(cfld)%ifld=IAVBLFLD(IGET(528))
             if(fld_info(cfld)%ntrange==0) then
               if (ifhr==0 .and. ifmin==0) then
                 fld_info(cfld)%tinvstat=0
               else
                 fld_info(cfld)%tinvstat=IFINCR
               endif
               fld_info(cfld)%ntrange=1
             end if
!$omp parallel do private(i,j,ii,jj)
             do j=1,jend-jsta+1
               jj = jsta+j-1
               do i=1,iend-ista+1
               ii = ista+i-1
                 datapd(i,j,cfld) = GRID1(ii,jj)
               enddo
             enddo
           endif
         ENDIF
!     'BUCKET1 SNOW  PRECIP '
         IF (IGET(529)>0.) THEN
!$omp parallel do private(i,j)
           DO J=JSTA,JEND
             DO I=ISTA,IEND
               IF (IFHR == 0 .AND. IFMIN == 0) THEN
                 GRID1(I,J) = 0.0
               ELSE
                 GRID1(I,J) = SNOW_BUCKET1(I,J)
               ENDIF
             ENDDO
           ENDDO
           IFINCR = NINT(PREC_ACC_DT1)
!           if(me==0)print*,'maxval BUCKET1 SNOWFALL: ', maxval(GRID1)
           if(grib=='grib2') then
             cfld=cfld+1
             fld_info(cfld)%ifld=IAVBLFLD(IGET(529))
             if(fld_info(cfld)%ntrange==0) then
               if (ifhr==0 .and. ifmin==0) then
                 fld_info(cfld)%tinvstat=0
               else
                 fld_info(cfld)%tinvstat=IFINCR
               endif
               fld_info(cfld)%ntrange=1
             end if
!$omp parallel do private(i,j,ii,jj)
             do j=1,jend-jsta+1
               jj = jsta+j-1
               do i=1,iend-ista+1
               ii = ista+i-1
                 datapd(i,j,cfld) = GRID1(ii,jj)
               enddo
             enddo
           endif
         ENDIF
!     'BUCKET1 GRAUPEL PRECIP '
         IF (IGET(530)>0.) THEN
!$omp parallel do private(i,j)
            DO J=JSTA,JEND
              DO I=ISTA,IEND
                IF (IFHR == 0 .AND. IFMIN == 0) THEN
                  GRID1(I,J) = 0.0
                ELSE
                  GRID1(I,J) = GRAUP_BUCKET1(I,J)
                ENDIF
              ENDDO
            ENDDO
            IFINCR = NINT(PREC_ACC_DT1)
!            print*,'maxval BUCKET1 GRAUPEL: ', maxval(GRID1)
            if(grib=='grib2') then
              cfld=cfld+1
              fld_info(cfld)%ifld=IAVBLFLD(IGET(530))
              if(fld_info(cfld)%ntrange==0) then
                if (ifhr==0 .and. ifmin==0) then
                  fld_info(cfld)%tinvstat=0
                else
                  fld_info(cfld)%tinvstat=IFINCR
                endif
                fld_info(cfld)%ntrange=1
              end if
!$omp parallel do private(i,j,ii,jj)
              do j=1,jend-jsta+1
                jj = jsta+j-1
                do i=1,iend-ista+1
                ii = ista+i-1
                  datapd(i,j,cfld) = GRID1(ii,jj)
                enddo
              enddo
            endif
         ENDIF
!     
!     INSTANTANEOUS PRECIPITATION TYPE.
!         print *,'in surfce,iget(160)=',iget(160),'iget(247)=',iget(247)
         IF (IGET(160)>0 .OR.(IGET(247)>0)) THEN

           allocate(sleet(ista:iend,jsta:jend,nalg),  rain(ista:iend,jsta:jend,nalg),   &
                    freezr(ista:iend,jsta:jend,nalg), snow(ista:iend,jsta:jend,nalg))
           allocate(zwet(ista:iend,jsta:jend))
           CALL CALWXT_POST(T,Q,PMID,PINT,HTM,LMH,PREC,ZINT,IWX1,ZWET)
!          write(*,*)' after first CALWXT_POST'


           IF (IGET(160)>0) THEN 
!$omp parallel do private(i,j,iwx)
             DO J=JSTA,JEND
               DO I=ISTA,IEND
                 IF(ZWET(I,J)<spval)THEN
                 IWX   = IWX1(I,J)
                 SNOW(I,J,1)   = MOD(IWX,2)
                 SLEET(I,J,1)  = MOD(IWX,4)/2
                 FREEZR(I,J,1) = MOD(IWX,8)/4
                 RAIN(I,J,1)   = IWX/8
                 ELSE
                 SNOW(I,J,1) = spval
                 SLEET(I,J,1) = spval
                 FREEZR(I,J,1) = spval
                 RAIN(I,J,1) = spval
                 ENDIF
               ENDDO
             ENDDO
           ENDIF
!     
!     LOWEST WET BULB ZERO HEIGHT
           IF (IGET(247)>0) THEN
             DO J=JSTA,JEND
               DO I=ISTA,IEND
                 GRID1(I,J) = ZWET(I,J)
               ENDDO
             ENDDO
             if(grib=='grib2') then
               cfld=cfld+1
               fld_info(cfld)%ifld=IAVBLFLD(IGET(247))
!$omp parallel do private(i,j,ii,jj)
               do j=1,jend-jsta+1
                 jj = jsta+j-1
                 do i=1,iend-ista+1
                 ii = ista+i-1
                   datapd(i,j,cfld) = GRID1(ii,jj)
                 enddo
               enddo
             endif
           ENDIF

!     DOMINANT PRECIPITATION TYPE
!GSM  IF DOMINANT PRECIP TYPE IS REQUESTED, 4 MORE ALGORITHMS
!GSM    WILL BE CALLED.  THE TALLIES ARE THEN SUMMED IN
!GSM    CALWXT_DOMINANT

           IF (IGET(160)>0) THEN   
!  RAMER ALGORITHM
             CALL CALWXT_RAMER_POST(T,Q,PMID,PINT,LMH,PREC,IWX1)
!            print *,'in SURFCE,me=',me,'IWX1=',IWX1(1:30,JSTA)
               
!     DECOMPOSE IWX1 ARRAY
!
!$omp parallel do private(i,j,iwx)
             DO J=JSTA,JEND
               DO I=ISTA,IEND
                 IWX   = IWX1(I,J)
                 SNOW(I,J,2)   = MOD(IWX,2)
                 SLEET(I,J,2)  = MOD(IWX,4)/2
                 FREEZR(I,J,2) = MOD(IWX,8)/4
                 RAIN(I,J,2)   = IWX/8
               ENDDO
             ENDDO

! BOURGOUIN ALGORITHM
             ISEED=44641*(INT(SDAT(1)-1)*24*31+INT(SDAT(2))*24+IHRST)+   &
     &             MOD(IFHR*60+IFMIN,44641)+4357
!            write(*,*)'in SURFCE,me=',me,'bef 1st CALWXT_BOURG_POST iseed=',iseed
             CALL CALWXT_BOURG_POST(IM,ISTA_2L,IEND_2U,ISTA,IEND,JM,JSTA_2L,JEND_2U,JSTA,JEND,LM,LP1,&
     &                              ISEED,G,PTHRESH,                       &
     &                              T,Q,PMID,PINT,LMH,PREC,ZINT,IWX1,me)
!            write(*,*)'in SURFCE,me=',me,'aft 1st CALWXT_BOURG_POST'
!            write(*,*)'in SURFCE,me=',me,'IWX1=',IWX1(1:30,JSTA),'PTHRESH=',PTHRESH

!     DECOMPOSE IWX1 ARRAY
!
!$omp parallel do private(i,j,iwx)
             DO J=JSTA,JEND
               DO I=ISTA,IEND
                 IWX   = IWX1(I,J)
                 SNOW(I,J,3)   = MOD(IWX,2)
                 SLEET(I,J,3)  = MOD(IWX,4)/2
                 FREEZR(I,J,3) = MOD(IWX,8)/4
                 RAIN(I,J,3)   = IWX/8
               ENDDO
             ENDDO

! REVISED NCEP ALGORITHM
             CALL CALWXT_REVISED_POST(T,Q,PMID,PINT,HTM,LMH,PREC,ZINT,IWX1)
!           print *,'in SURFCE,me=',me,'IWX1=',IWX1(1:30,JSTA)
!     DECOMPOSE IWX1 ARRAY
!
!$omp parallel do private(i,j,iwx)
             DO J=JSTA,JEND
               DO I=ISTA,IEND
                 IWX   = IWX1(I,J)
                 SNOW(I,J,4)   = MOD(IWX,2)
                 SLEET(I,J,4)  = MOD(IWX,4)/2
                 FREEZR(I,J,4) = MOD(IWX,8)/4
                 RAIN(I,J,4)   = IWX/8
               ENDDO
             ENDDO
              
! EXPLICIT ALGORITHM (UNDER 18 NOT ADMITTED WITHOUT PARENT OR GUARDIAN)
 
             IF(imp_physics==5 .or. imp_physics==85 .or. imp_physics==95)then
               CALL CALWXT_EXPLICIT_POST(LMH,THS,PMID,PREC,SR,F_RimeF,IWX1)
             else
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ISTA,IEND
                   IWX1(I,J) = 0
                 ENDDO
               ENDDO
             end if
!           print *,'in SURFCE,me=',me,'IWX1=',IWX1(1:30,JSTA)
!     DECOMPOSE IWX1 ARRAY
!
!$omp parallel do private(i,j,iwx)
             DO J=JSTA,JEND
               DO I=ISTA,IEND
                 IWX   = IWX1(I,J)
                 SNOW(I,J,5)   = MOD(IWX,2)
                 SLEET(I,J,5)  = MOD(IWX,4)/2
                 FREEZR(I,J,5) =  MOD(IWX,8)/4
                 RAIN(I,J,5)   = IWX/8
               ENDDO
             ENDDO
               
             allocate(domr(ista:iend,jsta:jend),  doms(ista:iend,jsta:jend),         &
                      domzr(ista:iend,jsta:jend), domip(ista:iend,jsta:jend))
             CALL CALWXT_DOMINANT_POST(PREC(ista_2l,jsta_2l),RAIN,FREEZR,SLEET,SNOW,  &
                                       DOMR,DOMZR,DOMIP,DOMS)
!            if ( me==0) print *,'after CALWXT_DOMINANT, no avrg'
!     SNOW.
             grid1 = spval
!$omp parallel do private(i,j)
             DO J=JSTA,JEND
               DO I=ISTA,IEND
                 if(prec(i,j) /= spval) GRID1(I,J) = DOMS(I,J)
               ENDDO
             ENDDO
             if(grib=='grib2') then
               cfld=cfld+1
               fld_info(cfld)%ifld=IAVBLFLD(IGET(551))
!$omp parallel do private(i,j,ii,jj)
               do j=1,jend-jsta+1
                 jj = jsta+j-1
                 do i=1,iend-ista+1
                 ii = ista+i-1
                   datapd(i,j,cfld) = GRID1(ii,jj)
                 enddo
               enddo
             endif
!     ICE PELLETS.
             grid1=spval
!$omp parallel do private(i,j)
             DO J=JSTA,JEND
               DO I=ISTA,IEND
                 if(prec(i,j)/=spval) GRID1(I,J) = DOMIP(I,J)
               ENDDO
             ENDDO
             if(grib=='grib2') then
               cfld=cfld+1
               fld_info(cfld)%ifld=IAVBLFLD(IGET(552))
!$omp parallel do private(i,j,ii,jj)
               do j=1,jend-jsta+1
                 jj = jsta+j-1
                 do i=1,iend-ista+1
                 ii = ista+i-1
                   datapd(i,j,cfld) = GRID1(ii,jj)
                 enddo
               enddo
             endif
!     FREEZING RAIN.
             grid1=spval 
!$omp parallel do private(i,j)
             DO J=JSTA,JEND
               DO I=ISTA,IEND
!                if (DOMZR(I,J) == 1) THEN
!                  PSFC(I,J)=PINT(I,J,NINT(LMH(I,J))+1)
!                  print *, 'aha ', I, J, PSFC(I,J)
!                  print *, FREEZR(I,J,1), FREEZR(I,J,2),
!     *  FREEZR(I,J,3), FREEZR(I,J,4), FREEZR(I,J,5)
!                endif
                 if(prec(i,j)/=spval)GRID1(I,J) = DOMZR(I,J)
               ENDDO
             ENDDO
             if(grib=='grib2') then
               cfld=cfld+1
               fld_info(cfld)%ifld=IAVBLFLD(IGET(553))
!$omp parallel do private(i,j,ii,jj)
               do j=1,jend-jsta+1
                 jj = jsta+j-1
                 do i=1,iend-ista+1
                 ii = ista+i-1
                   datapd(i,j,cfld) = GRID1(ii,jj)
                 enddo
               enddo
             endif
!     RAIN.
             grid1=spval 
!$omp parallel do private(i,j)
             DO J=JSTA,JEND
               DO I=ISTA,IEND
                 if(prec(i,j)/=spval)GRID1(I,J) = DOMR(I,J)
               ENDDO
             ENDDO
             if(grib=='grib2') then
               cfld=cfld+1
               fld_info(cfld)%ifld=IAVBLFLD(IGET(160))
!$omp parallel do private(i,j,ii,jj)
               do j=1,jend-jsta+1
                 jj = jsta+j-1
                 do i=1,iend-ista+1
                 ii = ista+i-1
                   datapd(i,j,cfld) = GRID1(ii,jj)
                 enddo
               enddo
             endif
           ENDIF
         ENDIF
!     
!     TIME AVERAGED PRECIPITATION TYPE.
         IF (IGET(317)>0) THEN

           if (.not. allocated(sleet))  allocate(sleet(ista:iend,jsta:jend,nalg))
           if (.not. allocated(rain))   allocate(rain(ista:iend,jsta:jend,nalg))
           if (.not. allocated(freezr)) allocate(freezr(ista:iend,jsta:jend,nalg))
           if (.not. allocated(snow))   allocate(snow(ista:iend,jsta:jend,nalg))
           if (.not. allocated(zwet))   allocate(zwet(ista:iend,jsta:jend))
           CALL CALWXT_POST(T,Q,PMID,PINT,HTM,LMH,AVGPREC,ZINT,IWX1,ZWET)

!$omp parallel do private(i,j,iwx)
           DO J=JSTA,JEND
             DO I=ISTA,IEND
               IF(ZWET(I,J)<spval)THEN
               IWX   = IWX1(I,J)
               SNOW(I,J,1)   = MOD(IWX,2)
               SLEET(I,J,1)  = MOD(IWX,4)/2
               FREEZR(I,J,1) = MOD(IWX,8)/4
               RAIN(I,J,1)   = IWX/8
               ELSE
               SNOW(I,J,1)   = spval
               SLEET(I,J,1)  = spval
               FREEZR(I,J,1) = spval
               RAIN(I,J,1)   = spval
               ENDIF
             ENDDO
           ENDDO
           if (allocated(zwet)) deallocate(zwet)
!          write(*,*)' after second CALWXT_POST me=',me
!          print *,'in SURFCE,me=',me,'IWX1=',IWX1(1:30,JSTA)

!     DOMINANT PRECIPITATION TYPE
!GSM  IF DOMINANT PRECIP TYPE IS REQUESTED, 4 MORE ALGORITHMS
!GSM    WILL BE CALLED.  THE TALLIES ARE THEN SUMMED IN
!GSM    CALWXT_DOMINANT

!  RAMER ALGORITHM
           CALL CALWXT_RAMER_POST(T,Q,PMID,PINT,LMH,AVGPREC,IWX1)
!          print *,'in SURFCE,me=',me,'IWX1=',IWX1(1:30,JSTA)
               
!     DECOMPOSE IWX1 ARRAY
!
!$omp parallel do private(i,j,iwx)
           DO J=JSTA,JEND
             DO I=ISTA,IEND
               IWX   = IWX1(I,J)
               SNOW(I,J,2)   = MOD(IWX,2)
               SLEET(I,J,2)  = MOD(IWX,4)/2
               FREEZR(I,J,2) = MOD(IWX,8)/4
               RAIN(I,J,2)   = IWX/8
             ENDDO
           ENDDO

! BOURGOUIN ALGORITHM
           ISEED=44641*(INT(SDAT(1)-1)*24*31+INT(SDAT(2))*24+IHRST)+   &
     &           MOD(IFHR*60+IFMIN,44641)+4357
!          write(*,*)'in SURFCE,me=',me,'bef sec CALWXT_BOURG_POST'
           CALL CALWXT_BOURG_POST(IM,ISTA_2L,IEND_2U,ISTA,IEND,JM,JSTA_2L,JEND_2U,JSTA,JEND,LM,LP1,&
     &                        ISEED,G,PTHRESH,                            &
     &                        T,Q,PMID,PINT,LMH,AVGPREC,ZINT,IWX1,me)
!          write(*,*)'in SURFCE,me=',me,'aft sec CALWXT_BOURG_POST'
!          print *,'in SURFCE,me=',me,'IWX1=',IWX1(1:30,JSTA)

!     DECOMPOSE IWX1 ARRAY
!
!$omp parallel do private(i,j,iwx)
           DO J=JSTA,JEND
             DO I=ISTA,IEND
               IWX   = IWX1(I,J)
               SNOW(I,J,3)   = MOD(IWX,2)
               SLEET(I,J,3)  = MOD(IWX,4)/2
               FREEZR(I,J,3) = MOD(IWX,8)/4
               RAIN(I,J,3)   = IWX/8
             ENDDO
           ENDDO

! REVISED NCEP ALGORITHM
           CALL CALWXT_REVISED_POST(T,Q,PMID,PINT,HTM,LMH,AVGPREC,ZINT,IWX1)
!          write(*,*)'in SURFCE,me=',me,'aft sec CALWXT_REVISED_BOURG_POST'
!          print *,'in SURFCE,me=',me,'IWX1=',IWX1(1:30,JSTA)
!     DECOMPOSE IWX1 ARRAY
!
!$omp parallel do private(i,j,iwx)
           DO J=JSTA,JEND
             DO I=ISTA,IEND
               IWX   = IWX1(I,J)
               SNOW(I,J,4)   = MOD(IWX,2)
               SLEET(I,J,4)  = MOD(IWX,4)/2
               FREEZR(I,J,4) = MOD(IWX,8)/4
               RAIN(I,J,4)   = IWX/8
             ENDDO
           ENDDO
              
! EXPLICIT ALGORITHM (UNDER 18 NOT ADMITTED WITHOUT PARENT OR GUARDIAN)
 
!          write(*,*)'in SURFCE,me=',me,'imp_physics=',imp_physics
           IF(imp_physics == 5)then
             CALL CALWXT_EXPLICIT_POST(LMH,THS,PMID,AVGPREC,SR,F_RimeF,IWX1)
           else
!$omp parallel do private(i,j)
             DO J=JSTA,JEND
               DO I=ISTA,IEND
                 IWX1(I,J) = 0
               ENDDO
             ENDDO
           end if
!          print *,'in SURFCE,me=',me,'IWX1=',IWX1(1:30,JSTA)
!     DECOMPOSE IWX1 ARRAY
!
!$omp parallel do private(i,j,iwx)
           DO J=JSTA,JEND
             DO I=ISTA,IEND
               IWX   = IWX1(I,J)
               SNOW(I,J,5)   = MOD(IWX,2)
               SLEET(I,J,5)  = MOD(IWX,4)/2
               FREEZR(I,J,5) = MOD(IWX,8)/4
               RAIN(I,J,5)   = IWX/8
             ENDDO
           ENDDO
               
!            print *,'me=',me,'before SNOW=',snow(1:10,JSTA,1:5)
!            print *,'me=',me,'before RAIN=',RAIN(1:10,JSTA,1:5)
!            print *,'me=',me,'before FREEZR=',FREEZR(1:10,JSTA,1:5)
!            print *,'me=',me,'before SLEET=',SLEET(1:10,JSTA,1:5)

           if (.not. allocated(domr))  allocate(domr(ista:iend,jsta:jend))
           if (.not. allocated(doms))  allocate(doms(ista:iend,jsta:jend))
           if (.not. allocated(domzr)) allocate(domzr(ista:iend,jsta:jend))
           if (.not. allocated(domip)) allocate(domip(ista:iend,jsta:jend))

           CALL CALWXT_DOMINANT_POST(AVGPREC,RAIN,FREEZR,SLEET,SNOW,    &
                                     DOMR,DOMZR,DOMIP,DOMS)
     
           ID(1:25) = 0
           ITPREC     = NINT(TPREC)
!mp
           if (ITPREC /= 0) then
             IFINCR     = MOD(IFHR,ITPREC)
             IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITPREC*60)
           else
             IFINCR     = 0
           endif
!mp
           ID(18)     = 0
           ID(19)     = IFHR
           IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
           ID(20)     = 3
           IF (IFINCR==0) THEN
             ID(18) = IFHR-ITPREC
           ELSE
             ID(18) = IFHR-IFINCR
             IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
           ENDIF

!          TPREC,'IFHR=',IFHR,'IFMIN=',IFMIN,'IFINCR=',IFINCR,'ID=',ID
!     SNOW.
            
           ID(8) = 143 
           grid1=spval
!$omp parallel do private(i,j)
           DO J=JSTA,JEND
             DO I=ISTA,IEND
               if(avgprec(i,j) /= spval) GRID1(I,J) = DOMS(I,J)
             ENDDO
           ENDDO
!           print *,'me=',me,'SNOW=',GRID1(1:10,JSTA)
           if(grib=='grib2') then
             cfld=cfld+1
             fld_info(cfld)%ifld=IAVBLFLD(IGET(555))
             if(ITPREC==0) then
              fld_info(cfld)%ntrange=0
             else
              fld_info(cfld)%ntrange=1
             endif
             fld_info(cfld)%tinvstat=IFHR-ID(18)

!$omp parallel do private(i,j,ii,jj)
             do j=1,jend-jsta+1
               jj = jsta+j-1
               do i=1,iend-ista+1
               ii = ista+i-1
                 datapd(i,j,cfld) = GRID1(ii,jj)
               enddo
             enddo
           endif
!     ICE PELLETS.
           ID(8) = 142 
           ITPREC     = NINT(TPREC)
!mp
           if (ITPREC /= 0) then
             IFINCR   = MOD(IFHR,ITPREC)
             IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITPREC*60)
           else
             IFINCR   = 0
           endif
!mp
           ID(18)     = 0
           ID(19)     = IFHR
           IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
           ID(20)     = 3
           IF (IFINCR==0) THEN
             ID(18) = IFHR-ITPREC
           ELSE
             ID(18) = IFHR-IFINCR
             IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
           ENDIF
           grid1=spval
!$omp parallel do private(i,j)
           DO J=JSTA,JEND
             DO I=ISTA,IEND
               if(avgprec(i,j)/=spval) GRID1(I,J) = DOMIP(I,J)
             ENDDO
           ENDDO
           if(grib=='grib2') then
             cfld=cfld+1
             fld_info(cfld)%ifld=IAVBLFLD(IGET(556))
             if(ITPREC==0) then
              fld_info(cfld)%ntrange=0
             else
              fld_info(cfld)%ntrange=1
             endif
             fld_info(cfld)%tinvstat=IFHR-ID(18)

!$omp parallel do private(i,j,ii,jj)
             do j=1,jend-jsta+1
               jj = jsta+j-1
               do i=1,iend-ista+1
               ii = ista+i-1
                 datapd(i,j,cfld) = GRID1(ii,jj)
               enddo
             enddo
           endif
!     FREEZING RAIN.
           ID(8) = 141
    
           ITPREC     = NINT(TPREC)
!mp
           if (ITPREC /= 0) then
             IFINCR   = MOD(IFHR,ITPREC)
             IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITPREC*60)
           else
             IFINCR   = 0
           endif
!mp
           ID(18)     = 0
           ID(19)     = IFHR
           IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
           ID(20)     = 3
           IF (IFINCR==0) THEN
             ID(18) = IFHR-ITPREC
           ELSE
             ID(18) = IFHR-IFINCR
             IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
           ENDIF
           grid1=spval
!$omp parallel do private(i,j)
           DO J=JSTA,JEND
             DO I=ISTA,IEND
!             if (DOMZR(I,J) == 1) THEN
!               PSFC(I,J)=PINT(I,J,NINT(LMH(I,J))+1)
!               print *, 'aha ', I, J, PSFC(I,J)
!               print *, FREEZR(I,J,1), FREEZR(I,J,2),
!     *  FREEZR(I,J,3), FREEZR(I,J,4), FREEZR(I,J,5)
!             endif
               if(avgprec(i,j)/=spval) GRID1(I,J) = DOMZR(I,J)
             ENDDO
           ENDDO
           if(grib=='grib2') then
             cfld=cfld+1
             fld_info(cfld)%ifld=IAVBLFLD(IGET(557))
             if(ITPREC==0) then
              fld_info(cfld)%ntrange=0
             else
              fld_info(cfld)%ntrange=1
             endif
             fld_info(cfld)%tinvstat=IFHR-ID(18)

!$omp parallel do private(i,j,ii,jj)
             do j=1,jend-jsta+1
               jj = jsta+j-1
               do i=1,iend-ista+1
               ii = ista+i-1
                 datapd(i,j,cfld) = GRID1(ii,jj)
               enddo
             enddo
           endif
!     RAIN.
           ID(8) = 140
    
           ITPREC     = NINT(TPREC)
!mp
           if (ITPREC /= 0) then
             IFINCR   = MOD(IFHR,ITPREC)
             IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITPREC*60)
           else
             IFINCR   = 0
           endif
!mp:w

           ID(18)     = 0
           ID(19)     = IFHR
           IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
           ID(20)     = 3
           IF (IFINCR==0) THEN
             ID(18) = IFHR-ITPREC
           ELSE
             ID(18) = IFHR-IFINCR
             IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
           ENDIF
           grid1=spval 
!$omp parallel do private(i,j)
           DO J=JSTA,JEND
             DO I=ISTA,IEND
               if(avgprec(i,j)/=spval) GRID1(I,J) = DOMR(I,J)
             ENDDO
           ENDDO
           if(grib=='grib2') then
             cfld=cfld+1
             fld_info(cfld)%ifld=IAVBLFLD(IGET(317))
             if(ITPREC==0) then
              fld_info(cfld)%ntrange=0
             else
              fld_info(cfld)%ntrange=1
             endif
             fld_info(cfld)%tinvstat=IFHR-ID(18)

!$omp parallel do private(i,j,ii,jj)
             do j=1,jend-jsta+1
               jj = jsta+j-1
               do i=1,iend-ista+1
               ii = ista+i-1
                 datapd(i,j,cfld) = GRID1(ii,jj)
               enddo
             enddo
           endif

         ENDIF

         if (allocated(rain))   deallocate(rain)
         if (allocated(snow))   deallocate(snow)
         if (allocated(sleet))  deallocate(sleet)
         if (allocated(freezr)) deallocate(freezr)

! GSD PRECIPITATION TYPE
         IF (IGET(407)>0 .or. IGET(559)>0 .or.  &
             IGET(560)>0 .or. IGET(561)>0) THEN

           if (.not. allocated(domr))  allocate(domr(ista:iend,jsta:jend))
           if (.not. allocated(doms))  allocate(doms(ista:iend,jsta:jend))
           if (.not. allocated(domzr)) allocate(domzr(ista:iend,jsta:jend))
           if (.not. allocated(domip)) allocate(domip(ista:iend,jsta:jend))

!$omp parallel do private(i,j)
           DO J=JSTA,JEND
             DO I=ISTA,IEND
               DOMS(I,J)  = 0.  !-- snow
               DOMR(I,J)  = 0.  !-- rain
               DOMZR(I,J) = 0.  !-- freezing rain
               DOMIP(I,J) = 0.  !-- ice pellets
             ENDDO
           ENDDO

           IF (MODELNAME .eq. 'FV3R') THEN
             DO J=JSTA,JEND
               DO I=ISTA,IEND
                 SNOW_BUCKET(I,J) = SNOW_BKT(I,J)
                 RAINNC_BUCKET(I,J) = 0.0
               ENDDO
             ENDDO
           ENDIF

           DO J=JSTA,JEND
             DO I=ISTA,IEND
!-- TOTPRCP is total 1-hour accumulated precipitation in  [m]
!-- RAP/HRRR and RRFS use 1-h bucket. GFS uses 3-h bucket
!-- so this section will need to be revised for GFS
               IF (MODELNAME .eq. 'FV3R') THEN
                 if(AVGPREC(I,J)/=spval)then
                   totprcp = (AVGPREC(I,J)*3600./DTQ2)
                 else
                   totprcp = 0.0
                 endif
               ELSE
                 totprcp = (RAINC_BUCKET(I,J) + RAINNC_BUCKET(I,J))*1.e-3
               ENDIF
               snowratio = 0.0
!-- This following warning message prints too often and is being commented out by
!-- Anders Jensen on 30 Jan 2024. I think that this warning message prints only when 
!-- graupel alone is reaching the surface. Total precipitation is interpolated 
!-- and precipitation from individual hydrometeor categories is not. Thus, when 
!-- total precipitation equals graupel precipitation and total precipitation is 
!-- interpolated and graupel precipitation is not, the two values may not be equal.
!               if(graup_bucket(i,j)*1.e-3 > totprcp.and.graup_bucket(i,j)/=spval)then
!                 print *,'WARNING - Graupel is higher than total precip at point',i,j
!                 print *,'totprcp,graup_bucket(i,j)*1.e-3,snow_bucket(i,j),rainnc_bucket',&
!                          totprcp,graup_bucket(i,j)*1.e-3,snow_bucket(i,j),rainnc_bucket(i,j)
!               endif

!  ---------------------------------------------------------------
!  Minimum 1h precipitation to even consider p-type specification
!      (0.0001 mm in 1h, very light precipitation)
!  ---------------------------------------------------------------
               if (totprcp-graup_bucket(i,j)*1.e-3 > 0.0000001) then
!          snowratio = snow_bucket(i,j)*1.e-3/totprcp            ! orig
!14aug15 - change from Stan and Trevor
!  ---------------------------------------------------------------
!      Snow-to-total ratio to be used below
!  ---------------------------------------------------------------
                  IF(MODELNAME == 'FV3R') THEN
                     snowratio = SR(i,j)
                  ELSE
                     snowratio = snow_bucket(i,j)*1.e-3 / (totprcp-graup_bucket(i,j)*1.e-3)
                  ENDIF
               endif
!-- 2-m temperature
               t2 = TSHLTR(I,J)*(PSHLTR(I,J)*1.E-5)**CAPA
!  ---------------------------------------------------------------
!--snow (or rain if T2m > 3 C)
!  ---------------------------------------------------------------
!--   SNOW is time step non-convective snow [m]
!     -- based on either instantaneous snowfall or 1h snowfall and
!     snowratio
               if( (SNOWNC(i,j)/DT > 0.2e-9 .and. snowratio>=0.25 .and. SNOWNC(i,j)/=spval) &
                       .or.                                         &
                   (totprcp>0.00001.and.snowratio>=0.25)) then
                   DOMS(i,j) = 1.
                 if (t2>=276.15) then
!              switch snow to rain if 2m temp > 3 deg
                   DOMR(I,J) = 1.
                   DOMS(I,J) = 0.
                 end if
               end if

!  ---------------------------------------------------------------
!-- rain/freezing rain
!  ---------------------------------------------------------------
!--   compute RAIN [m/s] from total convective and non-convective precipitation
               rainl = (1. - SR(i,j))*prec(i,j)/DT
!-- in RUC RAIN is in cm/h and the limit is 1.e-3,
!-- converted to m/s will be 2.8e-9
               if((rainl > 2.8e-9 .and. snowratio<0.60) .or.      &
                 (totprcp>0.00001 .and. snowratio<0.60)) then

                 if (t2>=273.15) then
!--rain
                   DOMR(I,J) = 1.
!               else if (tmax(i,j)>273.15) then
!14aug15 - stan
                 else
!-- freezing rain
                   DOMZR(I,J) = 1.
                 endif
               endif

!  ---------------------------------------------------------------
!-- graupel/ice pellets vs. snow or rain
!  ---------------------------------------------------------------
!-- GRAUPEL is time step non-convective graupel in [m]
               if(GRAUPELNC(i,j)/DT > 1.e-9 .and. GRAUPELNC(i,j)/=spval) then
                 if (t2<=276.15) then
!                 This T2m test excludes convectively based hail
!                   from cold-season ice pellets.

!            check for max rain mixing ratio
!              if it's > 0.05 g/kg, => ice pellets
                   if (qrmax(i,j)>0.000005) then
                     if(GRAUPELNC(i,j) > 0.5*SNOWNC(i,j)) then
!                if (instantaneous graupel fall rate > 0.5*
!                     instantaneous snow fall rate, ....
!-- diagnose ice pellets
                       DOMIP(I,J) = 1.

! -- If graupel is greater than rain,
!        report graupel only
! in RUC --> if (3.6E5*gex2(i,j,8)>   gex2(i,j,6)) then
                       if ((GRAUPELNC(i,j)/DT) > rainl) then
                         DOMIP(I,J) = 1.
                         DOMZR(I,J) = 0.
                         DOMR(I,J)  = 0.
! -- If rain is greater than 4x graupel,
!        report rain only
! in RUC -->  else if (gex2(i,j,6)>4.*3.6E5*gex2(i,j,8)) then
                       else if (rainl > (4.*GRAUPELNC(i,j)/DT)) then
                         DOMIP(I,J) = 0.
                       end if

                     else   !  instantaneous graupel fall rate <
                        !    0.5 * instantaneous snow fall rate
!                snow  -- ensure snow is diagnosed  (no ice pellets)
                       DOMS(i,j)=1.
                     end if
                   else     !  if qrmax is not > 0.00005
!              snow
                     DOMS(i,j)=1.
                   end if

                 else       !  if t2 >= 3 deg C
!              rain
                   DOMR(I,J) = 1.
                 end if     !  End of t2 if/then loop

               end if       !  End of GRAUPELNC if/then loop

             ENDDO
           ENDDO


        !write (6,*)' Snow/rain ratio'
        !write (6,*)' max/min 1h-SNOWFALL in [cm]',   &
        !      maxval(snow_bucket)*0.1,minval(snow_bucket)*0.1

        DO J=JSTA,JEND
        DO I=ISTA,IEND
           do icat=1,10
           if (snow_bucket(i,j)*0.1<0.1*float(icat).and.     &
               snow_bucket(i,j)*0.1>0.1*float(icat-1)) then
                  cnt_snowratio(icat)=cnt_snowratio(icat)+1
           end if
           end do
        end do
        end do

        !write (6,*) 'Snow ratio point counts'
        !   do icat=1,10
        !write (6,*) icat, cnt_snowratio(icat)
        !   end do

        icnt_snow_rain_mixed = 0
        DO J=JSTA,JEND
          DO I=ISTA,IEND
            if (DOMR(i,j)==1 .and. DOMS(i,j)==1) then
               icnt_snow_rain_mixed = icnt_snow_rain_mixed + 1
            endif
          end do
        end do

        !write (6,*) 'No. of mixed snow/rain p-type diagnosed=',   &
        !    icnt_snow_rain_mixed


!     SNOW.
!$omp parallel do private(i,j)
            DO J=JSTA,JEND
              DO I=ISTA,IEND
                GRID1(I,J)=DOMS(I,J)
              ENDDO
            ENDDO
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(559))
!$omp parallel do private(i,j,ii,jj)
            do j=1,jend-jsta+1
              jj = jsta+j-1
              do i=1,iend-ista+1
              ii = ista+i-1
                datapd(i,j,cfld) = GRID1(ii,jj)
              enddo
            enddo
           endif
!     ICE PELLETS.
!$omp parallel do private(i,j)
            DO J=JSTA,JEND
              DO I=ISTA,IEND
                GRID1(I,J) = DOMIP(I,J)
!             if (DOMIP(I,J) == 1) THEN
!               print *, 'ICE PELLETS at I,J ', I, J
!             endif
              ENDDO
            ENDDO
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(560))
!$omp parallel do private(i,j,ii,jj)
            do j=1,jend-jsta+1
              jj = jsta+j-1
              do i=1,iend-ista+1
              ii = ista+i-1
                datapd(i,j,cfld) = GRID1(ii,jj)
              enddo
            enddo
           endif
!     FREEZING RAIN.
!$omp parallel do private(i,j)
            DO J=JSTA,JEND
              DO I=ISTA,IEND
!             if (DOMZR(I,J) == 1) THEN
!               PSFC(I,J)=PINT(I,J,NINT(LMH(I,J))+1)
!               print *, 'FREEZING RAIN AT I,J ', I, J, PSFC(I,J)
!             endif
                GRID1(I,J) = DOMZR(I,J)
              ENDDO
            ENDDO
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(561))
!$omp parallel do private(i,j,ii,jj)
            do j=1,jend-jsta+1
              jj = jsta+j-1
              do i=1,iend-ista+1
              ii = ista+i-1
                datapd(i,j,cfld) = GRID1(ii,jj)
              enddo
            enddo
           endif
!     RAIN.
!$omp parallel do private(i,j)
            DO J=JSTA,JEND
              DO I=ISTA,IEND
                GRID1(I,J) = DOMR(I,J)
              ENDDO
            ENDDO
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(407))
!$omp parallel do private(i,j,ii,jj)
            do j=1,jend-jsta+1
              jj = jsta+j-1
              do i=1,iend-ista+1
              ii = ista+i-1
                datapd(i,j,cfld) = GRID1(ii,jj)
              enddo
            enddo
           endif

        ENDIF ! End of GSD PRECIPITATION TYPE
!     
        if (allocated(psfc))  deallocate(psfc)
        if (allocated(domr))  deallocate(domr)
        if (allocated(doms))  deallocate(doms)
        if (allocated(domzr)) deallocate(domzr)
        if (allocated(domip)) deallocate(domip)
!
!
!***  BLOCK 5.  SURFACE EXCHANGE FIELDS.
!     
!     TIME AVERAGED SURFACE LATENT HEAT FLUX.
         IF (IGET(042)>0) THEN
          IF(MODELNAME == 'NCAR'.OR.MODELNAME=='RSM' .OR. &
             MODELNAME=='RAPR')THEN
             GRID1=SPVAL
             ID(1:25)=0
          ELSE  
            IF(ASRFC>0.)THEN
              RRNUM=1./ASRFC
            ELSE
              RRNUM=0.
            ENDIF
            DO J=JSTA,JEND
            DO I=ISTA,IEND
	     IF(SFCLHX(I,J)/=SPVAL)THEN
              GRID1(I,J)=-1.*SFCLHX(I,J)*RRNUM !change the sign to conform with Grib
	     ELSE
	      GRID1(I,J)=SFCLHX(I,J)
	     END IF 
            ENDDO
            ENDDO
            ID(1:25) = 0
            ITSRFC     = NINT(TSRFC)
	    IF(ITSRFC /= 0) then
             IFINCR     = MOD(IFHR,ITSRFC)
	     IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITSRFC*60)
	    ELSE
	     IFINCR     = 0
            endif
            ID(19)     = IFHR
	    IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
            ID(20)     = 3
            IF (IFINCR==0) THEN
               ID(18) = IFHR-ITSRFC
            ELSE
               ID(18) = IFHR-IFINCR
	       IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
            ENDIF
            IF (ID(18)<0) ID(18) = 0
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(042))
            if(ITSRFC>0) then
               fld_info(cfld)%ntrange=1
            else
               fld_info(cfld)%ntrange=0
            endif
            fld_info(cfld)%tinvstat=IFHR-ID(18)
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
           endif
          END IF 
         ENDIF
!
!     TIME AVERAGED SURFACE SENSIBLE HEAT FLUX.
         IF (IGET(043)>0) THEN
          IF(MODELNAME == 'NCAR'.OR.MODELNAME=='RSM' .OR. &
             MODELNAME=='RAPR')THEN
	    GRID1=SPVAL
	    ID(1:25)=0
	  ELSE
            IF(ASRFC>0.)THEN
              RRNUM=1./ASRFC
            ELSE
              RRNUM=0.
            ENDIF
            DO J=JSTA,JEND
            DO I=ISTA,IEND
	     IF(SFCSHX(I,J)/=SPVAL)THEN
              GRID1(I,J) = -1.* SFCSHX(I,J)*RRNUM !change the sign to conform with Grib
	     ELSE
	      GRID1(I,J)=SFCSHX(I,J)
	     END IF  
            ENDDO
            ENDDO
            ID(1:25) = 0
            ITSRFC     = NINT(TSRFC)
	    IF(ITSRFC /= 0) then
             IFINCR     = MOD(IFHR,ITSRFC)
	     IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITSRFC*60)
	    ELSE
	     IFINCR     = 0
            endif
            ID(19)     = IFHR
	    IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
            ID(20)     = 3
            IF (IFINCR==0) THEN
               ID(18) = IFHR-ITSRFC
            ELSE
               ID(18) = IFHR-IFINCR
	       IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
            ENDIF
            IF (ID(18)<0) ID(18) = 0
	  END IF  
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(043))
            if(ITSRFC>0) then
               fld_info(cfld)%ntrange=1
            else
               fld_info(cfld)%ntrange=0
            endif
            fld_info(cfld)%tinvstat=IFHR-ID(18)
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
           endif
         ENDIF
!     
!     TIME AVERAGED SUB-SURFACE SENSIBLE HEAT FLUX.
         IF (IGET(135)>0) THEN
          IF(MODELNAME == 'NCAR'.OR.MODELNAME=='RSM' .OR. &
             MODELNAME=='RAPR')THEN
	    GRID1=SPVAL
	    ID(1:25)=0
	  ELSE
            IF(ASRFC>0.)THEN
              RRNUM=1./ASRFC
            ELSE
              RRNUM=0.
            ENDIF
            GRID1=SPVAL
            DO J=JSTA,JEND
            DO I=ISTA,IEND
             if(SUBSHX(I,J)/=spval) GRID1(I,J) = SUBSHX(I,J)*RRNUM
            ENDDO
            ENDDO
            ID(1:25) = 0
            ITSRFC     = NINT(TSRFC)
            IF(ITSRFC /= 0) then
             IFINCR     = MOD(IFHR,ITSRFC)
	     IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITSRFC*60)
	    ELSE
	     IFINCR     = 0
            endif
            ID(19)     = IFHR
	    IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
            ID(20)     = 3
            IF (IFINCR==0) THEN
               ID(18) = IFHR-ITSRFC
            ELSE
               ID(18) = IFHR-IFINCR
	       IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
            ENDIF
            IF (ID(18)<0) ID(18) = 0
	  END IF  
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(135))
            if(ITSRFC>0) then
               fld_info(cfld)%ntrange=1
            else
               fld_info(cfld)%ntrange=0
            endif
            fld_info(cfld)%tinvstat=IFHR-ID(18)
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
           endif
         ENDIF
!     
!     TIME AVERAGED SNOW PHASE CHANGE HEAT FLUX.
         IF (IGET(136)>0) THEN
          IF(MODELNAME == 'NCAR'.OR.MODELNAME=='RSM' .OR. &
             MODELNAME=='RAPR')THEN
	    GRID1=SPVAL
	    ID(1:25)=0
	  ELSE
            IF(ASRFC>0.)THEN
              RRNUM=1./ASRFC
            ELSE
              RRNUM=0.
            ENDIF
            GRID1=SPVAL
            DO J=JSTA,JEND
            DO I=ISTA,IEND
             if(SNOPCX(I,J)/=spval) GRID1(I,J) = SNOPCX(I,J)*RRNUM
            ENDDO
            ENDDO
            ID(1:25) = 0
            ITSRFC     = NINT(TSRFC)
            IF(ITSRFC /= 0) then
             IFINCR     = MOD(IFHR,ITSRFC)
	     IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITSRFC*60)
	    ELSE
	     IFINCR     = 0
            endif
            ID(19)     = IFHR
	    IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
            ID(20)     = 3
            IF (IFINCR==0) THEN
               ID(18) = IFHR-ITSRFC
            ELSE
               ID(18) = IFHR-IFINCR
	       IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
            ENDIF
            IF (ID(18)<0) ID(18) = 0
	  END IF  
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(136))
            if(ITSRFC>0) then
               fld_info(cfld)%ntrange=1
            else
               fld_info(cfld)%ntrange=0
            endif
            fld_info(cfld)%tinvstat=IFHR-ID(18)
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
           endif
         ENDIF
!     
!     TIME AVERAGED SURFACE MOMENTUM FLUX.
         IF (IGET(046)>0) THEN
          IF(MODELNAME == 'NCAR'.OR.MODELNAME=='RSM' .OR. &
             MODELNAME=='RAPR')THEN
	    GRID1=SPVAL
	    ID(1:25)=0
	  ELSE
            IF(ASRFC>0.)THEN
              RRNUM=1./ASRFC
            ELSE
              RRNUM=0.
            ENDIF
            DO J=JSTA,JEND
            DO I=ISTA,IEND
	     IF(SFCUVX(I,J)/=SPVAL)THEN
              GRID1(I,J) = SFCUVX(I,J)*RRNUM
	     ELSE
	      GRID1(I,J) = SFCUVX(I,J)
	     END IF  
            ENDDO
            ENDDO
            ID(1:25) = 0
            ITSRFC     = NINT(TSRFC)
            IF(ITSRFC /= 0) then
             IFINCR     = MOD(IFHR,ITSRFC)
	     IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITSRFC*60)
	    ELSE
	     IFINCR     = 0
            endif
            ID(19)     = IFHR
	    IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
            ID(20)     = 3
            IF (IFINCR==0) THEN
               ID(18) = IFHR-ITSRFC
            ELSE
               ID(18) = IFHR-IFINCR
	       IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
            ENDIF
            IF (ID(18)<0) ID(18) = 0
	  END IF  
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(046))
            if(ITSRFC>0) then
               fld_info(cfld)%ntrange=1
            else
               fld_info(cfld)%ntrange=0
            endif
            fld_info(cfld)%tinvstat=IFHR-ID(18)
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
           endif
         ENDIF
!
!     TIME AVERAGED SURFACE ZONAL MOMENTUM FLUX.
         IF (IGET(269)>0) THEN
          IF(MODELNAME == 'NCAR'.OR.MODELNAME=='RSM' .OR. &
             MODELNAME=='RAPR')THEN
            GRID1=SPVAL
            ID(1:25)=0
          ELSE
            IF(ASRFC>0.)THEN
              RRNUM=1./ASRFC
            ELSE
              RRNUM=0.
            ENDIF
            GRID1=SPVAL
            DO J=JSTA,JEND
            DO I=ISTA,IEND
             if(SFCUX(I,J)/=spval) GRID1(I,J) = SFCUX(I,J)*RRNUM
            ENDDO
            ENDDO
            ID(1:25) = 0
            ITSRFC     = NINT(TSRFC)
            IF(ITSRFC /= 0) then
             IFINCR     = MOD(IFHR,ITSRFC)
             IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITSRFC*60)
            ELSE
             IFINCR     = 0
            endif
            ID(19)     = IFHR
            IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
            ID(20)     = 3
            IF (IFINCR==0) THEN
               ID(18) = IFHR-ITSRFC
            ELSE
               ID(18) = IFHR-IFINCR
               IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
            ENDIF
            IF (ID(18)<0) ID(18) = 0
          END IF
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(269))
            if(ITSRFC>0) then
               fld_info(cfld)%ntrange=1
            else
               fld_info(cfld)%ntrange=0
            endif
            fld_info(cfld)%tinvstat=IFHR-ID(18)
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
           endif
         ENDIF
!
!     TIME AVERAGED SURFACE MOMENTUM FLUX.
         IF (IGET(270)>0) THEN
          IF(MODELNAME == 'NCAR'.OR.MODELNAME=='RSM' .OR. &
             MODELNAME=='RAPR')THEN
            GRID1=SPVAL
            ID(1:25)=0
          ELSE
            IF(ASRFC>0.)THEN
              RRNUM=1./ASRFC
            ELSE
              RRNUM=0.
            ENDIF
            GRID1=SPVAL
            DO J=JSTA,JEND
            DO I=ISTA,IEND
             if(SFCVX(I,J)/=spval) GRID1(I,J) = SFCVX(I,J)*RRNUM
            ENDDO
            ENDDO
            ID(1:25) = 0
            ITSRFC     = NINT(TSRFC)
            IF(ITSRFC /= 0) then
             IFINCR     = MOD(IFHR,ITSRFC)
             IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITSRFC*60)
            ELSE
             IFINCR     = 0
            endif
            ID(19)     = IFHR
            IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
            ID(20)     = 3
            IF (IFINCR==0) THEN
               ID(18) = IFHR-ITSRFC
            ELSE
               ID(18) = IFHR-IFINCR
               IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
            ENDIF
            IF (ID(18)<0) ID(18) = 0
          END IF
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(270))
            if(ITSRFC>0) then
               fld_info(cfld)%ntrange=1
            else
               fld_info(cfld)%ntrange=0
            endif
            fld_info(cfld)%tinvstat=IFHR-ID(18)
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
           endif
         ENDIF
!     
!     ACCUMULATED SURFACE EVAPORATION
         IF (IGET(047)>0) THEN
            GRID1=SPVAL
            DO J=JSTA,JEND
              DO I=ISTA,IEND
               if(SFCEVP(I,J)/=spval) GRID1(I,J) = SFCEVP(I,J)*1000.
              ENDDO
            ENDDO
            ID(1:25) = 0
            ITPREC     = NINT(TPREC)
!mp
	if (ITPREC /= 0) then
         IFINCR     = MOD(IFHR,ITPREC)
	 IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITPREC*60)
	else
	 IFINCR     = 0
	endif
!mp
            ID(18)     = 0
            ID(19)     = IFHR
	    IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
            ID(20)     = 4
            IF (IFINCR==0) THEN
             ID(18) = IFHR-ITPREC
            ELSE
             ID(18) = IFHR-IFINCR
	     IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
            ENDIF
            IF (ID(18)<0) ID(18) = 0
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(047))
            if(ITPREC>0) then
               fld_info(cfld)%ntrange=1
            else
               fld_info(cfld)%ntrange=0
            endif
            fld_info(cfld)%tinvstat=IFHR-ID(18)
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)

           endif
         ENDIF
!     
!     ACCUMULATED POTENTIAL EVAPORATION
         IF (IGET(137)>0) THEN
            GRID1=SPVAL
            DO J=JSTA,JEND
              DO I=ISTA,IEND
               if(POTEVP(I,J)/=spval) GRID1(I,J) = POTEVP(I,J)*1000.
              ENDDO
            ENDDO
            ID(1:25) = 0
            ITPREC     = NINT(TPREC)
!mp
	if (ITPREC /= 0) then
         IFINCR     = MOD(IFHR,ITPREC)
	 IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITPREC*60)
	else
	 IFINCR     = 0
	endif
!mp
            ID(18)     = 0
            ID(19)     = IFHR
	    IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
            ID(20)     = 4
            IF (IFINCR==0) THEN
             ID(18) = IFHR-ITPREC
            ELSE
             ID(18) = IFHR-IFINCR
	     IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
            ENDIF
            IF (ID(18)<0) ID(18) = 0
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(137))
            if(ITPREC>0) then
               fld_info(cfld)%ntrange=1
            else
               fld_info(cfld)%ntrange=0
            endif
            fld_info(cfld)%tinvstat=IFHR-ID(18)
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
           endif
         ENDIF
!     
!     ROUGHNESS LENGTH.
      IF (IGET(044)>0) THEN
          DO J=JSTA,JEND
            DO I=ISTA,IEND
              GRID1(I,J) = Z0(I,J)
            ENDDO
          ENDDO
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(044))
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
           endif
      ENDIF
!     
!     FRICTION VELOCITY.
      IF (IGET(045)>0) THEN
          DO J=JSTA,JEND
            DO I=ISTA,IEND
              GRID1(I,J) = USTAR(I,J)
            ENDDO
          ENDDO
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(045))
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
           endif
      ENDIF
!     
!     SURFACE DRAG COEFFICIENT.
! dong add missing value for cd
      IF (IGET(132)>0) THEN
         GRID1=spval
         CALL CALDRG(EGRID1(ista_2l:iend_2u,jsta_2l:jend_2u))
            DO J=JSTA,JEND
            DO I=ISTA,IEND
             IF(USTAR(I,J) < spval) GRID1(I,J)=EGRID1(I,J)
            ENDDO
            ENDDO
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(132))
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
           endif
      ENDIF

      write_cd: IF(IGET(924)>0) THEN
         DO J=JSTA,JEND
            DO I=ISTA,IEND
               GRID1(I,J)=CD10(I,J)
            ENDDO
         ENDDO
         if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(924))
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
         endif
      ENDIF write_cd
      write_ch: IF(IGET(923)>0) THEN
         DO J=JSTA,JEND
            DO I=ISTA,IEND
               GRID1(I,J)=CH10(I,J)
            ENDDO
         ENDDO
         if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(923))
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
         endif
      ENDIF write_ch
!     
!     MODEL OUTPUT SURFACE U AND/OR V COMPONENT WIND STRESS
      IF ( (IGET(900)>0) .OR. (IGET(901)>0) ) THEN
!
!        MODEL OUTPUT SURFACE U COMPONENT WIND STRESS.
         IF (IGET(900)>0) THEN
            DO J=JSTA,JEND
            DO I=ISTA,IEND
             GRID1(I,J)=MDLTAUX(I,J)
            ENDDO
            ENDDO
         if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(900))
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
         endif

         ENDIF
!
!        MODEL OUTPUT SURFACE V COMPONENT WIND STRESS
         IF (IGET(901)>0) THEN
            DO J=JSTA,JEND
            DO I=ISTA,IEND
             GRID1(I,J)=MDLTAUY(I,J)
            ENDDO
            ENDDO
         if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(901))
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
         endif
         ENDIF
      ENDIF
!
!     SURFACE U AND/OR V COMPONENT WIND STRESS
      IF ( (IGET(133)>0) .OR. (IGET(134)>0) ) THEN
! dong add missing value
        GRID1 = spval
         IF(MODELNAME /= 'FV3R') &
         CALL CALTAU(EGRID1(ista:iend,jsta:jend),EGRID2(ista:iend,jsta:jend))
!     
!        SURFACE U COMPONENT WIND STRESS.
! dong for FV3, directly use model output
         IF (IGET(133)>0) THEN
            DO J=JSTA,JEND
              DO I=ISTA,IEND
                IF(MODELNAME == 'FV3R') THEN
                  GRID1(I,J)=SFCUXI(I,J)
                ELSE
                  GRID1(I,J)=EGRID1(I,J)
                ENDIF
              ENDDO
            ENDDO
!     
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(133))
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
           endif
         ENDIF
!     
!        SURFACE V COMPONENT WIND STRESS
         IF (IGET(134)>0) THEN
            DO J=JSTA,JEND
            DO I=ISTA,IEND
              IF(MODELNAME == 'FV3R') THEN
                GRID1(I,J)=SFCVXI(I,J)
              ELSE
                GRID1(I,J)=EGRID2(I,J)
              END IF
            ENDDO
            ENDDO
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(134))
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
           endif
         ENDIF
      ENDIF
!     
!     GRAVITY U AND/OR V COMPONENT STRESS
      IF ( (IGET(315)>0) .OR. (IGET(316)>0) ) THEN
!     
!        GRAVITY U COMPONENT WIND STRESS.
         IF (IGET(315)>0) THEN
            DO J=JSTA,JEND
              DO I=ISTA,IEND
                GRID1(I,J) = GTAUX(I,J)
              ENDDO
            ENDDO
            ID(1:25) = 0
            ITSRFC     = NINT(TSRFC)
            IF(ITSRFC /= 0) then
             IFINCR     = MOD(IFHR,ITSRFC)
             IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITSRFC*60)
            ELSE
             IFINCR     = 0
            endif
            ID(19)     = IFHR
            IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
            ID(20)     = 3
            IF (IFINCR==0) THEN
               ID(18) = IFHR-ITSRFC
            ELSE
               ID(18) = IFHR-IFINCR
               IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
            ENDIF
            IF (ID(18)<0) ID(18) = 0
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(315))
            if(ITSRFC==0) then
              fld_info(cfld)%ntrange=0
            else
              fld_info(cfld)%ntrange=1
            endif
            fld_info(cfld)%tinvstat=IFHR-ID(18)
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
           endif
         ENDIF
!     
!        SURFACE V COMPONENT WIND STRESS
         IF (IGET(316)>0) THEN
            DO J=JSTA,JEND
            DO I=ISTA,IEND
             GRID1(I,J)=GTAUY(I,J)
            ENDDO
            ENDDO
            ID(1:25) = 0
	    ITSRFC     = NINT(TSRFC)
            IF(ITSRFC /= 0) then
             IFINCR     = MOD(IFHR,ITSRFC)
	     IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITSRFC*60)
	    ELSE
	     IFINCR     = 0
            endif
            ID(19)     = IFHR
	    IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
            ID(20)     = 3
            IF (IFINCR==0) THEN
               ID(18) = IFHR-ITSRFC
            ELSE
               ID(18) = IFHR-IFINCR
	       IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
            ENDIF
            IF (ID(18)<0) ID(18) = 0
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(316))
            if(ITSRFC==0) then
              fld_info(cfld)%ntrange=0
            else
              fld_info(cfld)%ntrange=1
            endif
            fld_info(cfld)%tinvstat=IFHR-ID(18)
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
           endif
         ENDIF
      ENDIF      
!     
!     INSTANTANEOUS SENSIBLE HEAT FLUX
      IF (IGET(154)>0) THEN
! dong add missing value to shtfl
        GRID1 = spval
        IF(MODELNAME=='NCAR'.OR.MODELNAME=='RSM' .OR. &
           MODELNAME=='RAPR')THEN
!4omp parallel do private(i,j)
          DO J=JSTA,JEND
            DO I=ISTA,IEND
               GRID1(I,J) = TWBS(I,J)
            ENDDO
          ENDDO
        ELSE
!4omp parallel do private(i,j)
          DO J=JSTA,JEND
            DO I=ISTA,IEND
               IF(TWBS(I,J) < spval) GRID1(I,J) = -TWBS(I,J)
            ENDDO
          ENDDO
        END IF
        if(grib=='grib2') then
          cfld=cfld+1
          fld_info(cfld)%ifld=IAVBLFLD(IGET(154))
          datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
        endif
      ENDIF
!     
!     INSTANTANEOUS LATENT HEAT FLUX
      IF (IGET(155)>0) THEN
! dong add missing value to lhtfl
        GRID1 = spval
        IF(MODELNAME=='NCAR'.OR.MODELNAME=='RSM' .OR. &
           MODELNAME=='RAPR')THEN
!4omp parallel do private(i,j)
          DO J=JSTA,JEND
            DO I=ISTA,IEND
               GRID1(I,J) = QWBS(I,J)
            ENDDO
          ENDDO
        ELSE
!4omp parallel do private(i,j)
          DO J=JSTA,JEND
            DO I=ISTA,IEND
               IF(QWBS(I,J) < spval) GRID1(I,J) = -QWBS(I,J)
            ENDDO
          ENDDO
        END IF
        if(grib=='grib2') then
          cfld=cfld+1
          fld_info(cfld)%ifld=IAVBLFLD(IGET(155))
          datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
        endif
      ENDIF
!     
!     SURFACE EXCHANGE COEFF
      IF (IGET(169)>0) THEN
            DO J=JSTA,JEND
            DO I=ISTA,IEND
             GRID1(I,J)=SFCEXC(I,J)
            ENDDO
            ENDDO
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(169))
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
           endif
      ENDIF
!     
!     GREEN VEG FRACTION
      IF (IGET(170)>0) THEN
            GRID1=SPVAL
            DO J=JSTA,JEND
            DO I=ISTA,IEND
             if(VEGFRC(I,J)/=spval) GRID1(I,J)=VEGFRC(I,J)*100.
            ENDDO
            ENDDO
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(170))
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
           endif
      ENDIF

!
!     MIN GREEN VEG FRACTION
      IF (IGET(726)>0) THEN
            GRID1=SPVAL
            DO J=JSTA,JEND
            DO I=ISTA,IEND
             if(shdmin(I,J)/=spval) GRID1(I,J)=shdmin(I,J)*100.
            ENDDO
            ENDDO
          if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(726))
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
           endif
      ENDIF
!
!     MAX GREEN VEG FRACTION
      IF (IGET(729)>0) THEN
            GRID1=SPVAL
            DO J=JSTA,JEND
            DO I=ISTA,IEND
             if(shdmax(I,J)/=spval) GRID1(I,J)=shdmax(I,J)*100.
            ENDDO
            ENDDO
          if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(729))
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
           endif
      ENDIF
!
!     LEAF AREA INDEX
      IF (MODELNAME == 'NCAR'.OR.MODELNAME=='NMM' .OR. &
          MODELNAME == 'FV3R' .OR. MODELNAME=='RAPR')THEN
      IF (iSF_SURFACE_PHYSICS == 2 .OR. MODELNAME=='FV3R' .OR. MODELNAME=='RAPR') THEN
        IF (IGET(254)>0) THEN
              if (me==0)print*,'starting LAI'
              DO J=JSTA,JEND
              DO I=ISTA,IEND
                IF (MODELNAME=='RAPR')THEN
                  GRID1(I,J)=LAI(I,J)
                ELSE IF (MODELNAME=='FV3R')THEN
                  GRID1(I,J)=XLAIXY(I,J)
                ELSE
                  GRID1(I,J) = XLAI
              ENDIF
            ENDDO
            ENDDO
          if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(254))
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
           endif
        ENDIF
      ENDIF
      ENDIF
!     
!     INSTANTANEOUS GROUND HEAT FLUX
      IF (IGET(152)>0) THEN
         DO J=JSTA,JEND
           DO I=ISTA,IEND
             GRID1(I,J)=GRNFLX(I,J)
           ENDDO
         ENDDO
         if(grib=='grib2') then
           cfld=cfld+1
           fld_info(cfld)%ifld=IAVBLFLD(IGET(152))
           datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
         endif
      ENDIF
!    VEGETATION TYPE
      IF (IGET(218)>0) THEN
         DO J=JSTA,JEND
           DO I=ISTA,IEND
             GRID1(I,J) = FLOAT(IVGTYP(I,J))
           ENDDO
         ENDDO
         if(grib=='grib2') then
           cfld=cfld+1
           fld_info(cfld)%ifld=IAVBLFLD(IGET(218))
           datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
         endif
      ENDIF
!
!    SOIL TYPE
      IF (IGET(219)>0) THEN
         DO J=JSTA,JEND
           DO I=ISTA,IEND
             GRID1(I,J) = FLOAT(ISLTYP(I,J))
           ENDDO
         ENDDO
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(219))
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
           endif
      ENDIF
!    SLOPE TYPE
      IF (IGET(223)>0) THEN
        DO J=JSTA,JEND
          DO I=ISTA,IEND
            GRID1(I,J) = FLOAT(ISLOPE(I,J))
          ENDDO
        ENDDO
        if(grib=='grib2') then
          cfld=cfld+1
          fld_info(cfld)%ifld=IAVBLFLD(IGET(223))
          datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
        endif
      ENDIF
!      if (me==0)print*,'starting computing canopy conductance'
!
! CANOPY CONDUCTANCE
! ONLY OUTPUT NEW LSM FIELDS FOR NMM AND ARW BECAUSE RSM USES OLD SOIL TYPES
      IF (MODELNAME == 'NCAR'.OR.MODELNAME=='NMM' .OR. &
          MODELNAME == 'FV3R' .OR. MODELNAME=='RAPR')THEN
      IF (IGET(220)>0 .OR. IGET(234)>0               &
     & .OR. IGET(235)>0 .OR. IGET(236)>0             &
     & .OR. IGET(237)>0 .OR. IGET(238)>0             &
     & .OR. IGET(239)>0 .OR. IGET(240)>0             &
     & .OR. IGET(241)>0 ) THEN
        IF (iSF_SURFACE_PHYSICS == 2 .OR. iSF_SURFACE_PHYSICS == 3) THEN    !NSOIL == 4
!          if(me==0)print*,'starting computing canopy conductance'
         allocate(rsmin(ista:iend,jsta:jend), smcref(ista:iend,jsta:jend), gc(ista:iend,jsta:jend), &
                  rcq(ista:iend,jsta:jend), rct(ista:iend,jsta:jend), rcsoil(ista:iend,jsta:jend), rcs(ista:iend,jsta:jend))
         DO J=JSTA,JEND
           DO I=ISTA,IEND
             IF( (abs(SM(I,J)-0.)   < 1.0E-5) .AND.     &
     &           (abs(SICE(I,J)-0.) < 1.0E-5) ) THEN
              IF(CZMEAN(I,J)>1.E-6) THEN
               FACTRS = CZEN(I,J)/CZMEAN(I,J)
              ELSE
               FACTRS = 0.0
              ENDIF
!              SOLAR=HBM2(I,J)*RSWIN(I,J)*FACTRS
              LLMH   = NINT(LMH(I,J))
              SOLAR  = RSWIN(I,J)*FACTRS
              SFCTMP = T(I,J,LLMH)
              SFCQ   = Q(I,J,LLMH)
              SFCPRS = PINT(I,J,LLMH+1)
!              IF(IVGTYP(I,J)==0)PRINT*,'IVGTYP ZERO AT ',I,J
!     &        ,SM(I,J)
              IVG = IVGTYP(I,J)
!              IF(IVGTYP(I,J)==0)IVG=7
!              CALL CANRES(SOLAR,SFCTMP,SFCQ,SFCPRS
!     &        ,SMC(I,J,1:NSOIL),GC(I,J),RC,IVG,ISLTYP(I,J))
!
              CALL CANRES(SOLAR,SFCTMP,SFCQ,SFCPRS                       &
     &                   ,SH2O(I,J,1:NSOIL),GC(I,J),RC,IVG,ISLTYP(I,J)   &
     &                   ,RSMIN(I,J),NROOTS(I,J),SMCWLT(I,J),SMCREF(I,J) &
     &                   ,RCS(I,J),RCQ(I,J),RCT(I,J),RCSOIL(I,J),SLDPTH)  
               IF(abs(SMCWLT(I,J)-0.5)<1.e-5)print*,       &
     &       'LARGE SMCWLT',i,j,SM(I,J),ISLTYP(I,J),SMCWLT(I,J)
             ELSE
              GC(I,J)     = 0.
              RSMIN(I,J)  = 0.
              NROOTS(I,J) = 0
              SMCWLT(I,J) = 0.
              SMCREF(I,J) = 0.
              RCS(I,J)    = 0.
              RCQ(I,J)    = 0.
              RCT(I,J)    = 0.
              RCSOIL(I,J) = 0.
             END IF
           ENDDO
         ENDDO

         IF (IGET(220)>0 )THEN
          DO J=JSTA,JEND
           DO I=ISTA,IEND
             GRID1(I,J) = GC(I,J)
           ENDDO
          ENDDO
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(220))
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
           endif
         ENDIF

         IF (IGET(234)>0 )THEN
          DO J=JSTA,JEND
           DO I=ISTA,IEND
             GRID1(I,J) = RSMIN(I,J)
           ENDDO
          ENDDO
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(234))
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
           endif
         ENDIF
	 
         IF (IGET(235)>0 )THEN
          DO J=JSTA,JEND
           DO I=ISTA,IEND
             GRID1(I,J) = FLOAT(NROOTS(I,J))
           ENDDO
          ENDDO
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(235))
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
           endif
         ENDIF

         IF (IGET(236)>0 )THEN
          DO J=JSTA,JEND
           DO I=ISTA,IEND
             GRID1(I,J) = SMCWLT(I,J)
           ENDDO
          ENDDO
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(236))
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
           endif
         ENDIF

         IF (IGET(237)>0 )THEN
          DO J=JSTA,JEND
           DO I=ISTA,IEND
             GRID1(I,J) = SMCREF(I,J)
           ENDDO
          ENDDO
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(237))
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
           endif
         ENDIF

         IF (IGET(238)>0 )THEN
          DO J=JSTA,JEND
           DO I=ISTA,IEND
             GRID1(I,J) = RCS(I,J)
           ENDDO
          ENDDO
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(238))
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
           endif
         ENDIF

         IF (IGET(239)>0 )THEN
          DO J=JSTA,JEND
           DO I=ISTA,IEND
             GRID1(I,J) = RCT(I,J)
           ENDDO
          ENDDO
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(239))
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
           endif
         ENDIF

         IF (IGET(240)>0 )THEN
          DO J=JSTA,JEND
           DO I=ISTA,IEND
             GRID1(I,J) = RCQ(I,J)
           ENDDO
          ENDDO
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(240))
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
           endif
         ENDIF	
         
         IF (IGET(241)>0 )THEN
          DO J=JSTA,JEND
           DO I=ISTA,IEND
             GRID1(I,J) = RCSOIL(I,J)
           ENDDO
          ENDDO
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(241))
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
           endif
         ENDIF

         if (allocated(rsmin))  deallocate(rsmin)
         if (allocated(smcref)) deallocate(smcref)
         if (allocated(rcq))    deallocate(rcq)
         if (allocated(rct))    deallocate(rct)
         if (allocated(rcsoil)) deallocate(rcsoil)
         if (allocated(rcs))    deallocate(rcs)
         if (allocated(gc))     deallocate(gc)


        ENDIF
      END IF
!GPL added endif here
      ENDIF
      IF(MODELNAME == 'GFS')THEN
! Outputting wilting point and field capacity for TIGGE
       IF(IGET(236)>0)THEN
!$omp parallel do private(i,j)
        DO J=JSTA,JEND
          DO I=ISTA,IEND
            GRID1(I,J) = smcwlt(i,j)
!            IF(isltyp(i,j)/=0)THEN
!              GRID1(I,J) = WLTSMC(isltyp(i,j))
!            ELSE
!              GRID1(I,J) = spval
!            END IF
          ENDDO
        ENDDO
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(236))
!$omp parallel do private(i,j,ii,jj)
            do j=1,jend-jsta+1
              jj = jsta+j-1
              do i=1,iend-ista+1
              ii = ista+i-1
                datapd(i,j,cfld) = GRID1(ii,jj)
              enddo
            enddo
           endif
       ENDIF
       
       IF(IGET(397)>0)THEN
!$omp parallel do private(i,j)
        DO J=JSTA,JEND
          DO I=ISTA,IEND
            GRID1(I,J) = fieldcapa(i,j)
!            IF(isltyp(i,j)/=0)THEN
!              GRID1(I,J) = REFSMC(isltyp(i,j))
!            ELSE
!              GRID1(I,J) = spval
!            END IF
          ENDDO
        ENDDO
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(397))
!$omp parallel do private(i,j,ii,jj)
            do j=1,jend-jsta+1
              jj = jsta+j-1
              do i=1,iend-ista+1
              ii = ista+i-1
                datapd(i,j,cfld) = GRID1(ii,jj)
              enddo
            enddo
           endif
       ENDIF
      END IF 
      IF(IGET(396)>0)THEN
!$omp parallel do private(i,j)
        DO J=JSTA,JEND
          DO I=ISTA,IEND
            GRID1(I,J) = suntime(i,j)
          ENDDO
        ENDDO
        ID(1:25) = 0
        ITSRFC     = NINT(TSRFC)
        IF(ITSRFC /= 0) then
          IFINCR     = MOD(IFHR,ITSRFC)
          IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITSRFC*60)
        ELSE
          IFINCR     = 0
        endif
        ID(19)     = IFHR
        IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
        ID(20)     = 3
        IF (IFINCR==0) THEN
           ID(18) = IFHR-ITSRFC
        ELSE
           ID(18) = IFHR-IFINCR
           IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
        ENDIF
        IF (ID(18)<0) ID(18) = 0
        if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(396))
            if(ITSRFC>0) then
               fld_info(cfld)%ntrange=1
            else
               fld_info(cfld)%ntrange=0
            endif
            fld_info(cfld)%tinvstat=IFHR-ID(18)
!$omp parallel do private(i,j,ii,jj)
            do j=1,jend-jsta+1
              jj = jsta+j-1
              do i=1,iend-ista+1
              ii = ista+i-1
                datapd(i,j,cfld) = GRID1(ii,jj)
              enddo
            enddo
        endif
      ENDIF    

      IF(IGET(517)>0)THEN
!$omp parallel do private(i,j)
        DO J=JSTA,JEND
          DO I=ISTA,IEND
            GRID1(I,J) = avgpotevp(i,j)
          ENDDO
        ENDDO
        ID(1:25) = 0
        ITSRFC     = NINT(TSRFC)
        IF(ITSRFC /= 0) then
          IFINCR     = MOD(IFHR,ITSRFC)
          IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITSRFC*60)
        ELSE
          IFINCR     = 0
        endif
        ID(19)     = IFHR
        IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
        ID(20)     = 3
        IF (IFINCR==0) THEN
           ID(18) = IFHR-ITSRFC
        ELSE
           ID(18) = IFHR-IFINCR
           IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
        ENDIF
        IF (ID(18)<0) ID(18) = 0
        if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(517))
            if(ITSRFC>0) then
               fld_info(cfld)%ntrange=1
            else
               fld_info(cfld)%ntrange=0
            endif
            fld_info(cfld)%tinvstat=IFHR-ID(18)
!$omp parallel do private(i,j,ii,jj)
            do j=1,jend-jsta+1
              jj = jsta+j-1
              do i=1,iend-ista+1
              ii = ista+i-1
                datapd(i,j,cfld) = GRID1(ii,jj)
              enddo
            enddo
        endif
      ENDIF

!     
!     
!       MODEL TOP REQUESTED BY CMAQ
      IF (IGET(282)>0) THEN
!$omp parallel do private(i,j)
            DO J=JSTA,JEND
              DO I=ISTA,IEND
                GRID1(I,J) = PT
              ENDDO
            ENDDO
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(282))
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
           endif
      ENDIF
!     
!       PRESSURE THICKNESS REQUESTED BY CMAQ
      IF (IGET(283)>0) THEN
            DO J=JSTA,JEND
            DO I=ISTA,IEND
             GRID1(I,J)=PDTOP
            ENDDO
            ENDDO
            ID(1:25) = 0
	    IF(ME == 0)THEN 
	     DO L=1,LM
	      IF(PMID(1,1,L)>=(PDTOP+PT))EXIT
	     END DO
!	     PRINT*,'hybrid boundary ',L
            END IF 
            CALL MPI_BCAST(L,1,MPI_INTEGER,0,mpi_comm_comp,irtn)
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(283))
            fld_info(cfld)%lvl1=1
            fld_info(cfld)%lvl2=L
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
           endif
      ENDIF
!      
!       SIGMA PRESSURE THICKNESS REQUESTED BY CMAQ
      IF (IGET(273)>0) THEN
            DO J=JSTA,JEND
            DO I=ISTA,IEND
             GRID1(I,J)=PD(I,J)
            ENDDO
            ENDDO
            IF(ME == 0)THEN
             DO L=1,LM
!              print*,'Debug CMAQ: ',L,PINT(1,1,LM+1),PD(1,1),PINT(1,1,L)
              IF((PINT(1,1,LM+1)-PD(1,1))<=(PINT(1,1,L)+1.00))EXIT
             END DO
!             PRINT*,'hybrid boundary ',L
            END IF
            CALL MPI_BCAST(L,1,MPI_INTEGER,0,mpi_comm_comp,irtn)
           if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(273))
            fld_info(cfld)%lvl1=L
            fld_info(cfld)%lvl2=LM+1
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
           endif
      ENDIF


!      TIME-AVERAGED EXCHANGE COEFFICIENTS FOR MASS REQUESTED FOR CMAQ
      IF (IGET(503)>0) THEN
            DO J=JSTA,JEND
            DO I=ISTA,IEND
             GRID1(I,J)=AKHSAVG(I,J)
            ENDDO
            ENDDO
            ID(1:25) = 0
	    ID(02)= 133
         ID(19)     = IFHR
         IF (IFHR==0) THEN
           ID(18) = 0
         ELSE
           ID(18) = IFHR - 1
         ENDIF
            ID(20)     = 3
         ITSRFC = NINT(TSRFC)
         if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(503))
            if(ITSRFC>0) then
              fld_info(cfld)%ntrange=1
            else
              fld_info(cfld)%ntrange=0
            endif
            fld_info(cfld)%tinvstat=IFHR-ID(18)
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
         endif
      ENDIF

!      TIME-AVERAGED EXCHANGE COEFFICIENTS FOR WIND REQUESTED FOR CMAQ
      IF (IGET(504)>0) THEN
            DO J=JSTA,JEND
            DO I=ISTA,IEND
             GRID1(I,J)=AKMSAVG(I,J)
            ENDDO
            ENDDO
            ID(1:25) = 0
	    ID(02)= 133
         ID(19)     = IFHR
         IF (IFHR==0) THEN
           ID(18) = 0
         ELSE
           ID(18) = IFHR - 1
         ENDIF
            ID(20)     = 3
         ITSRFC = NINT(TSRFC)
         if(grib=='grib2') then
            cfld=cfld+1
            fld_info(cfld)%ifld=IAVBLFLD(IGET(504))
            if(ITSRFC>0) then
              fld_info(cfld)%ntrange=1
            else
              fld_info(cfld)%ntrange=0
            endif
            fld_info(cfld)%tinvstat=IFHR-ID(18)
            datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
         endif

      ENDIF

      RETURN
      END
!-------------------------------------------------------------------------------------
!> qpf_comp() Read in QPF threshold for exceedance grid. Calculate exceedance grid.
!> 
!> @param[in] compfile character File name for reference grid.
!> @param[in] fcst integer Forecast length in hours.
!> @param[in] igetfld integer ID of grib2 field. 

      subroutine qpf_comp(igetfld,compfile,fcst)

      use ctlblk_mod, only: SPVAL,JSTA,JEND,IM,DTQ2,IFHR,IFMIN,TPREC,GRIB,   &
                            MODELNAME,JM,CFLD,DATAPD,FLD_INFO,JSTA_2L,JEND_2U,&
                            ISTA,IEND,ISTA_2L,IEND_2U,ME
      use rqstfld_mod, only: IGET, ID, LVLS, IAVBLFLD
      use grib2_module, only: read_grib2_head, read_grib2_sngle
      use vrbls2d, only: AVGPREC, AVGPREC_CONT
      implicit none
      character(len=256), intent(in) :: compfile
      integer, intent(in) :: igetfld,fcst
      integer :: trange,invstat
      real, dimension(ista:iend,jsta:jend) :: outgrid

      real, allocatable, dimension(:,:) :: mscValue

      integer :: nx, ny, nz, ntot, mscNlon, mscNlat, height
      integer :: ITPREC, IFINCR
      real :: rlonmin, rlatmax
      real*8 rdx, rdy

      logical :: file_exists

      integer :: i, j, k, ii, jj

      outgrid = 0

!     Read in reference grid.
      INQUIRE(FILE=compfile, EXIST=file_exists)
      if (file_exists) then
         call read_grib2_head(compfile,nx,ny,nz,rlonmin,rlatmax,&
                  rdx,rdy)
         mscNlon=nx
         mscNlat=ny
         if (.not. allocated(mscValue)) then
            allocate(mscValue(mscNlon,mscNlat))
         endif
         ntot = nx*ny
         call read_grib2_sngle(compfile,ntot,height,mscValue)
      else
         if(me==0)write(*,*) 'WARNING: FFG file not available for hour: ', fcst
      endif

!     Set GRIB variables.
      ID(1:25) = 0
      ITPREC     = NINT(TPREC)
      if (ITPREC /= 0) then
         IFINCR     = MOD(IFHR,ITPREC)
         IF(IFMIN >= 1)IFINCR= MOD(IFHR*60+IFMIN,ITPREC*60)
      else
         IFINCR     = 0
      endif
      ID(18)     = 0
      ID(19)     = IFHR
      IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
      ID(20)     = 4
      IF (IFINCR==0) THEN
         ID(18) = IFHR-ITPREC
      ELSE
         ID(18) = IFHR-IFINCR
         IF(IFMIN >= 1)ID(18)=IFHR*60+IFMIN-IFINCR
      ENDIF

!     Calculate exceedance grid.
      IF(MODELNAME == 'GFS' .OR. MODELNAME == 'FV3R') THEN
!      !$omp parallel do private(i,j)
       IF (file_exists) THEN
         DO J=JSTA,JEND
            DO I=ISTA,IEND
               IF (IFHR .EQ. 0 .OR. fcst .EQ. 0) THEN
                  outgrid(I,J) = 0.0
               ELSE IF (mscValue(I,J) .LE. 0.0) THEN
                  outgrid(I,J) = 0.0
               ELSE IF (fcst .EQ. 1 .AND. AVGPREC(I,J)*FLOAT(ID(19)-ID(18))*3600.*1000./DTQ2 .GT. mscValue(I,J)) THEN
                  outgrid(I,J) = 1.0
               ELSE IF (fcst .GT. 1 .AND. AVGPREC_CONT(I,J)*FLOAT(IFHR)*3600.*1000./DTQ2 .GT. mscValue(I,J)) THEN
                  outgrid(I,J) = 1.0
               ENDIF
            ENDDO
         ENDDO
       ENDIF
      ENDIF
!      write(*,*) 'FFG MAX, MIN:', &
!                  maxval(mscValue),minval(mscValue)
      IF (ID(18).LT.0) ID(18) = 0

!     Set GRIB2 variables.
      IF(fcst .EQ. 1) THEN
         IF(ITPREC>0) THEN
            trange = (IFHR-ID(18))/ITPREC
         ELSE
            trange = 0
         ENDIF
         invstat = ITPREC
         IF(trange .EQ. 0) THEN
            IF (IFHR .EQ. 0) THEN
               invstat = 0
            ELSE
               invstat = 1
            ENDIF
            trange = 1
         ENDIF
      ELSE
         trange = 1
         IF (IFHR .EQ. fcst) THEN
            invstat = fcst
         ELSE
            invstat = 0
         ENDIF
      ENDIF

      IF(grib=='grib2') then
         cfld=cfld+1
         fld_info(cfld)%ifld=IAVBLFLD(IGET(igetfld))
         fld_info(cfld)%ntrange=trange
         fld_info(cfld)%tinvstat=invstat
!$omp parallel do private(i,j,ii,jj)
         do j=1,jend-jsta+1
            jj = jsta+j-1
            do i=1,iend-ista+1
            ii = ista+i-1
               datapd(i,j,cfld) = outgrid(ii,jj)
            enddo
         enddo
      endif

      RETURN

      end subroutine qpf_comp
