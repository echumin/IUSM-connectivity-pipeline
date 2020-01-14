#!/bin/bash
dwi2response tournier -voxels /datay2/chumin-F31/data/AUD/PRISMA/PPE20109/DWI/MRtrix/csd_selected_voxels.nii.gz -force -mask /datay2/chumin-F31/data/AUD/PRISMA/PPE20109/DWI/EDDY/b0_brain_mask.nii.gz -fslgrad /datay2/chumin-F31/data/AUD/PRISMA/PPE20109/DWI/EDDY/eddy_output.eddy_rotated_bvecs /datay2/chumin-F31/data/AUD/PRISMA/PPE20109/DWI/DTIfit/3_DWI.bval /datay2/chumin-F31/data/AUD/PRISMA/PPE20109/DWI/EDDY/eddy_output.nii.gz /datay2/chumin-F31/data/AUD/PRISMA/PPE20109/DWI/MRtrix/tournier_response.txt
dwi2fod csd -fslgrad /datay2/chumin-F31/data/AUD/PRISMA/PPE20109/DWI/EDDY/eddy_output.eddy_rotated_bvecs /datay2/chumin-F31/data/AUD/PRISMA/PPE20109/DWI/DTIfit/3_DWI.bval -mask /datay2/chumin-F31/data/AUD/PRISMA/PPE20109/DWI/EDDY/b0_brain_mask.nii.gz /datay2/chumin-F31/data/AUD/PRISMA/PPE20109/DWI/EDDY/eddy_output.nii.gz /datay2/chumin-F31/data/AUD/PRISMA/PPE20109/DWI/MRtrix/tournier_response.txt /datay2/chumin-F31/data/AUD/PRISMA/PPE20109/DWI/MRtrix/csd_fod.mif
5ttgen fsl -premasked /datay2/chumin-F31/data/AUD/PRISMA/PPE20109/DWI/MRtrix/rT1_brain.nii.gz /datay2/chumin-F31/data/AUD/PRISMA/PPE20109/DWI/MRtrix/fsl5tt.nii.gz
tckgen /datay2/chumin-F31/data/AUD/PRISMA/PPE20109/DWI/MRtrix/csd_fod.mif /datay2/chumin-F31/data/AUD/PRISMA/PPE20109/DWI/MRtrix/10m_streamlines.tck -act /datay2/chumin-F31/data/AUD/PRISMA/PPE20109/DWI/MRtrix/fsl5tt.nii.gz -crop_at_gmwmi -algorithm iFOD2 -seed_dynamic /datay2/chumin-F31/data/AUD/PRISMA/PPE20109/DWI/MRtrix/csd_fod.mif -select 10M
tcksift -force -act /datay2/chumin-F31/data/AUD/PRISMA/PPE20109/DWI/MRtrix/fsl5tt.nii.gz -term_number 1M /datay2/chumin-F31/data/AUD/PRISMA/PPE20109/DWI/MRtrix/10m_streamlines.tck /datay2/chumin-F31/data/AUD/PRISMA/PPE20109/DWI/MRtrix/csd_fod.mif /datay2/chumin-F31/data/AUD/PRISMA/PPE20109/DWI/MRtrix/1m_sift_streamlines.tck
tck2connectome -assignment_radial_search 2 -symmetric -zero_diagonal -force /datay2/chumin-F31/data/AUD/PRISMA/PPE20109/DWI/MRtrix/1m_sift_streamlines.tck /datay2/chumin-F31/data/AUD/PRISMA/PPE20109/DWI/MRtrix/DWI_GM_frontostriatal.nii.gz /datay2/chumin-F31/data/AUD/PRISMA/PPE20109/DWI/MRtrix/1M_2mm_radial_frontostraital_connectome.csv
