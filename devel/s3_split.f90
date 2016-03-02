!-----------------------------------------------------------------------
! Copyright (c) 2011-2016  Remko Scharroo
! See LICENSE.TXT file for copying and redistribution conditions.
!
! This program is free software: you can redistribute it and/or modify
! it under the terms of the GNU Lesser General Public License as
! published by the Free Software Foundation, either version 3 of the
! License, or (at your option) any later version.
!
! This program is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU Lesser General Public License for more details.
!-----------------------------------------------------------------------

!*s3_split -- Split and combine Sentinel-3 files into pass files
!
! Read Sentinel-3 standard_measurements.nc or reduced_measurements.nc
! granules and combine them (and split them) into pass files.
! The input file names are read from
! standard input. The individual pass files will be named
! <destdir>/cCCC/S3A_*_CCC_PPP.nc, where CCC is the cycle number and
! PPP the pass number. The directory <destdir>/cCCC will be created if needed.
!
! This program does not rely on ORF files, like ogdrsplit does
!-----------------------------------------------------------------------
program s3_split

use rads
use rads_misc
use rads_netcdf
use typesizes
use netcdf

character(len=rads_cmdl) :: arg, filenm, dimnm, destdir, product_name
character(len=rads_strl) :: exclude_list = ','
integer(fourbyteint), parameter :: mpass = 254 * 500
real(eightbytereal), parameter :: sec2000 = 473299200d0
integer(fourbyteint) :: i0, i, ncid1, nrec, ios, varid, n_ignore = 0, nr_passes = 770, &
	pass_number = 0, cycle_number = 0, pass_in, cycle_in
real(eightbytereal), allocatable :: time(:), lat(:)

! Print description, if requested

if (iargc() < 1) then
	write (*,1300)
	stop
endif
1300 format ('s3_split -- Combine/split Sentinel-3 files into pass files'// &
'syntax: s3_split [options] destdir < list'//'where'/ &
'  destdir           : Destination directory (appends c???/*.nc)'/ &
'  list              : List of input files names'// &
'where [options] are:' / &
'  -iNRECS           : Ignore up to NRECS record chunks to move to existing files (def: 0)' / &
'  -xVAR1[,VAR2,...] : Exclude variable(s) from copying')

! Read options and destination directory

do i = 1,iargc()
	call getarg (i,arg)
	if (arg(:2) == '-i') then
		read (arg(3:),*) n_ignore
	else if (arg(:2) == '-x') then
		exclude_list = trim(exclude_list) // arg(3:len_trim(arg)) // ','
	else
		destdir = arg
	endif
enddo

! Open the input file(s)

do

! Read file name

610 format ('Splitting : ',a)
	read (*,'(a)',iostat=ios) filenm
	if (ios /= 0) stop
	write (*,610) trim(filenm)
	call nfs(nf90_open(filenm,nf90_nowrite,ncid1))

! Read the time dimension

	call nfs(nf90_inquire_dimension(ncid1,1,dimnm,nrec))
	if (dimnm /= 'time_01') stop 'Error reading time dimension'
	allocate (time(nrec),lat(nrec))
	call nfs(nf90_inq_varid(ncid1,'time_01',varid))
	call nfs(nf90_get_var(ncid1,varid,time))
	call nfs(nf90_inq_varid(ncid1,'lat_01',varid))
	call nfs(nf90_get_var(ncid1,varid,lat))
	call nfs(nf90_get_att(ncid1,nf90_global,'pass_number',pass_in))
	call nfs(nf90_get_att(ncid1,nf90_global,'cycle_number',cycle_in))
	call nfs(nf90_get_att(ncid1,nf90_global,'product_name',product_name))

! For first file: set cycle/pass number to input ones

	if (pass_number == 0) then
		pass_number = pass_in
		cycle_number = cycle_in
	endif

! Look if files rolled/rolls over to new pass

	i0 = 1
	if (cycle_in == cycle_number .and. pass_in == pass_number) then
		do i = 2,nrec
			if (lat(i) > lat(i-1) .neqv. modulo(pass_number,2) == 1) then
				call copyfile (i0, i-1)
				pass_number = pass_number + 1
				if (pass_number > 770) then
					cycle_number = cycle_number + 1
					pass_number = 1
				endif
			endif
		enddo
	else
		pass_number = pass_in
		cycle_number = cycle_in
	endif
	call copyfile (i0, nrec)
	call nfs(nf90_close(ncid1))
	deallocate (time, lat)
enddo

contains

!***********************************************************************
! Copy the contents of the input file to a new output file

subroutine copyfile (rec0, rec1)
integer(fourbyteint), intent(inout) :: rec0
integer(fourbyteint), intent(in) :: rec1
integer(fourbyteint) :: nrec,ncid2,varid,varid2,xtype,ndims,dimids(2),natts,i,nvars,idxin(2)=1,idxut(2)=1,dimlen
character(len=rads_naml) :: outnm,attnm,varnm
real(eightbytereal) :: time2(2)
real(eightbytereal), allocatable :: darr1(:)
integer(fourbyteint), allocatable :: iarr1(:)
logical :: exist
character(len=26) :: date(2)

! Skip empty data chunks

if (rec1 < rec0) return
call nfs(nf90_inquire(ncid1,nvariables=nvars,nattributes=natts))

! Open the output file. Make directory if needed.

605 format (a,'/c',i3.3)
610 format (a,'/c',i3.3,'/',a,i3.3,'_',i3.3,'.nc')
620 format ('... Records : ',3i6,' : ',a,1x,a,' - ',a,a)

write (outnm,605) trim(destdir),cycle_number
inquire (file=outnm,exist=exist)
if (.not.exist) call system('mkdir -p '//outnm)
write (outnm,610) trim(destdir),cycle_number,product_name(:15),cycle_number,pass_number
inquire (file=outnm,exist=exist)

if (exist) then

! Match up the last time in the existing file with times in the input file

	call nfs(nf90_open(outnm,nf90_write,ncid2))
	call nfs(nf90_set_fill(ncid2,nf90_nofill,i))
	call nfs(nf90_inquire_dimension(ncid2,1,len=dimlen))
	idxin(2)=dimlen
	call nfs(nf90_get_var(ncid2,1,time2(1),idxin(1:1)))
	call nfs(nf90_get_var(ncid2,1,time2(2),idxin(2:2)))
	do while (time(rec0) < time2(2)+0.5d0 .and. rec0 <= rec1)
		rec0 = rec0 + 1
	enddo
	nrec = rec1 - rec0 + 1
	if (nrec <= 0) then
		call nfs(nf90_close(ncid2))
		return
	endif
	call nfs(nf90_redef(ncid2))

else

! Create a new file

	call nfs(nf90_create(outnm,nf90_write+nf90_nofill,ncid2))
	call nfs(nf90_set_fill(ncid2,nf90_nofill,i))
	dimlen = 0

! Create the time dimension

	call nfs(nf90_def_dim(ncid2,'time_01',nf90_unlimited,i))
	time2(1) = time(rec0)

! Copy all the variable definitions and attributes

	varid2 = 0
	do varid = 0, nvars
		if (varid > 0) then
			call nfs(nf90_inquire_variable(ncid1,varid,varnm,xtype,ndims,dimids,natts))
			if (excluded(varnm) .or. ndims > 1 .or. dimids(1) > 1) cycle
			call nfs(nf90_def_var(ncid2,varnm,xtype,dimids(1:ndims),varid2))
		endif
		do i = 1,natts
			call nfs(nf90_inq_attname(ncid1,varid,i,attnm))
			if (varid == 0 .and. pass_number /= pass_in .and. attnm(1:7) == 'equator') cycle
			call nfs(nf90_copy_att(ncid1,varid,attnm,ncid2,varid2))
		enddo
	enddo
endif

! Initialize

nrec = rec1 - rec0 + 1
idxin(2) = rec0
idxut(2) = dimlen + 1
time2(2) = time(rec1)
call strf1985f(date(1),time(rec0)+sec2000)
call strf1985f(date(2),time(rec1)+sec2000)
write (*,620) rec0,rec1,nrec,trim(outnm),date(1:2)
call strf1985f(date(1),time2(1)+sec2000)
call strf1985f(date(2),time2(2)+sec2000)

allocate (darr1(nrec),iarr1(nrec))

! Overwrite cycle/pass attributes

call nfs(nf90_put_att(ncid2,nf90_global,'cycle_number',cycle_number))
call nfs(nf90_put_att(ncid2,nf90_global,'pass_number',pass_number))
call nfs(nf90_put_att(ncid2,nf90_global,'absolute_pass_number',(cycle_number-1)*nr_passes+pass_number-54))
call nfs(nf90_put_att(ncid2,nf90_global,'first_meas_time',date(1)))
call nfs(nf90_put_att(ncid2,nf90_global,'last_meas_time',date(2)))
call nfs(nf90_enddef(ncid2))

! Copy all data elements

varid2 = 0
do varid = 1,nvars
	call nfs(nf90_inquire_variable(ncid1,varid,varnm,xtype,ndims,dimids,natts))
	if (excluded(varnm) .or. ndims > 1 .or. dimids(1) > 1) cycle
	varid2 = varid2 + 1
	if (xtype == nf90_double) then
		call nfs(nf90_get_var(ncid1,varid ,darr1,idxin(2:2)))
		call nfs(nf90_put_var(ncid2,varid2,darr1,idxut(2:2)))
	else
		call nfs(nf90_get_var(ncid1,varid ,iarr1,idxin(2:2)))
		call nfs(nf90_put_var(ncid2,varid2,iarr1,idxut(2:2)))
	endif
enddo

deallocate (darr1,iarr1)

call nfs(nf90_close(ncid2))

end subroutine copyfile

function excluded (varnm)
character(len=*), intent(in) :: varnm
logical :: excluded
excluded = (index(exclude_list,','//trim(varnm)//',') > 0)
end function excluded

end program s3_split
