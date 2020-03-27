function [paths,flags,configs,parcs]=f_T1_prepare_B(paths,flags,configs,parcs)
%                               F_T1_PREPARE_B
% Registration of subject anatomical T1 image to MNI with subsequent
% transformation of parcellation images into subject native space.
%
% Segmetation of subject T1 into tissue-types.
%
% Contributors:
%   Joaquin Goni, Purdue University
%   Joey Contreras, University Southern California
%   Mario Dzemidzic, Indiana University School of Medicine
%   Evgeny Chumin, Indiana University School of Medicine

%% Registration of subjec to MNI
if flags.T1.reg2MNI==1
    % Transform subject T1 into MNI space, then using inverse matrices
    % transform yeo7, yeo17, shen parcellations and MNI ventricles mask
    % into subject native space.
    disp('Registration between Native T1 and MNI space') 
    [paths,configs,parcs]=fsl_registration_parcellations_non_linear(paths,configs,parcs);
end

%% Tissue-type segmentation; cleaning; and gray matter masking of parcellations
if flags.T1.seg==1
    disp('Tissue-type Segmentation') 
    % Check that T1_brain image indeed exists.
    fileIn = fullfile(paths.T1.dir,'T1_brain.nii.gz');
    if exist(fileIn,'file') ~=2 
        warning('%s not found. Exiting...',fileIn')
        return
    end
    
    % FSL fast tissue-type segmentation (GM, WM, CSF)
    sentence = sprintf('%s/fast -H %s %s',paths.FSL,configs.T1.segfastH,fileIn);
    [~,result] = system(sentence); %#ok<*ASGLU>

    %% CSF masks
    fileIn = fullfile(paths.T1.dir,'T1_brain_seg.nii.gz');
    fileOut = fullfile(paths.T1.dir,'T1_CSF_mask');
    if exist(sprintf(fileIn),'file') ~= 2
        warning('%s not found. Exiting...',fileIn')
        return
    end
        
    sentence = sprintf('%s/fslmaths %s -thr %s -uthr 1 %s',...
        paths.FSL,fileIn,configs.T1.masklowthr,fileOut);
    [~,result] = system(sentence);
    sentence = sprintf('%s/fslmaths %s/T1_CSF_mask.nii.gz -mul -1 -add 1 %s/T1_CSF_mask_inv.nii.gz',...
        paths.FSL,paths.T1.dir,paths.T1.dir);
    [~,result] = system(sentence);  
    
    %% Subcortical masks
    fileOut = fullfile(paths.T1.dir,'T1_subcort_seg.nii.gz');
    if exist(fileOut,'file') ~= 2
        warning('%s not found. Exiting...',fileIn')
        return
    end

    fileIn = fullfile(paths.T1.dir,'T1_subcort_mask.nii.gz');
    sentence = sprintf('%s/fslmaths %s -bin %s',paths.FSL,fileOut,fileIn);
    [~,result] = system(sentence);

    fileMas = fullfile(paths.T1.dir,'T1_CSF_mask_inv.nii.gz');
    sentence = sprintf('%s/fslmaths %s -mas %s %s',...
        paths.FSL,fileIn,fileMas,fileIn);
    [~,result] = system(sentence);

    sentence = sprintf('%s/fslmaths %s -mul -1 -add 1 %s/T1_subcort_mask_inv.nii.gz',...
        paths.FSL,fileIn,paths.T1.dir);
    [~,result] = system(sentence);
    
    %% Adding FIRST subcortical into tissue segmentation
    sentence = sprintf('%s/fslmaths %s/T1_brain_seg -mul %s/T1_subcort_mask_inv %s/T1_brain_seg_best',...
        paths.FSL,paths.T1.dir,paths.T1.dir,paths.T1.dir);
    [~,result] = system(sentence);

    sentence = sprintf('%s/fslmaths %s/T1_subcort_mask -mul 2 %s/T1_subcort_seg_add',...
        paths.FSL,paths.T1.dir,paths.T1.dir);
    [~,result] = system(sentence);

    sentence = sprintf('%s/fslmaths %s/T1_brain_seg_best -add %s/T1_subcort_seg_add %s/T1_brain_seg_best',...
        paths.FSL,paths.T1.dir,paths.T1.dir,paths.T1.dir);
    [~,result] = system(sentence);

    %% Separating Tissue types
    listTissue = {'CSF','GM','WM'};
    fileIn = fullfile(paths.T1.dir,'T1_brain_seg_best.nii.gz');
    for i=1:3 % 1=CSF 2=GM 3=WM
        fileOut = fullfile(paths.T1.dir,sprintf('T1_%s_mask',listTissue{i}));
        sentence = sprintf('%s/fslmaths %s -thr %d -uthr %d -div %d %s',...
            paths.FSL,fileIn,i,i,i,fileOut);
        [~,result] = system(sentence);
        %Erode each tissue mask
        sentence=sprintf('%s/fslmaths %s -ero %s_eroded',paths.FSL,fileOut,fileOut);
        [~,result]=system(sentence);
        if i == 3 % if WM
            WMeroded = fullfile(paths.T1.dir,'T1_WM_mask_eroded.nii.gz');
            % 2nd WM erosion 
            sentence = sprintf('%s/fslmaths %s -ero %s',paths.FSL,WMeroded,WMeroded);
            [~,result]=system(sentence);
            % 3rd WM erosion
            sentence = sprintf('%s/fslmaths %s -ero %s',paths.FSL,WMeroded,WMeroded);
            [~,result]=system(sentence);
        end
    end
    
    % apply as CSF ventricles mask 
    fileIn = fullfile(paths.T1.dir,'T1_CSF_mask_eroded.nii.gz');
    fileOut = fullfile(paths.T1.dir,'T1_CSFvent_mask_eroded');
    fileMas = fullfile(paths.T1.dir,'T1_mask_CSFvent.nii.gz');
    if exist(fileMas,'file') ~= 2
        warning('%s not found. Exiting...',fileMas')
        return
    end
    sentence = sprintf('%s/fslmaths %s -mas %s %s',paths.FSL,fileIn,fileMas,fileOut);
    [~,result] = system(sentence);
    
%% WM CSF sandwich
     disp('WM/CSF sandwich')
    % Remove any gray matter voxels that are withing one dilation of CSF and white matter.
    % Dilate WM mask
     fileIn = fullfile(paths.T1.dir,'T1_WM_mask.nii.gz');
     fileOut = fullfile(paths.T1.dir,'T1_WM_mask_dil');
     sentence = sprintf('%s/fslmaths %s -dilD %s',paths.FSL,fileIn,fileOut);
     [~,result] = system(sentence);

     % Dilate CSF mask
     fileIn = fullfile(paths.T1.dir,'T1_CSF_mask.nii.gz');
     fileOut = fullfile(paths.T1.dir,'T1_CSF_mask_dil');
     sentence = sprintf('%s/fslmaths %s -dilD %s',paths.FSL,fileIn,fileOut);
     [~,result] = system(sentence);
     
     % Add the dilated masks together.
     fileIn1 = fullfile(paths.T1.dir,'T1_WM_mask_dil.nii.gz');
     fileIn2 = fullfile(paths.T1.dir,'T1_CSF_mask_dil.nii.gz');
     fileOut = fullfile(paths.T1.dir,'T1_WM_CSF_sandwich.nii.gz');
     sentence = sprintf('%s/fslmaths %s -add %s %s',paths.FSL,fileIn1,fileIn2,fileOut);
     [~,result] = system(sentence);
     
     % Theshold the image at 2, isolating WM, CSF interface.
     fileIn = fullfile(paths.T1.dir,'T1_WM_CSF_sandwich.nii.gz');
     fileOut = fullfile(paths.T1.dir,'T1_WM_CSF_sandwich.nii.gz');
     sentence = sprintf('%s/fslmaths %s -thr 2 %s',paths.FSL,fileIn,fileOut);
     [~,result] = system(sentence);
     
     % Multiply the interface by the native space ventricle mask.
     fileIn1 = fullfile(paths.T1.dir,'T1_WM_CSF_sandwich.nii.gz');
     fileIn2 = fullfile(paths.T1.dir,'T1_mask_CSFvent.nii.gz');
     fileOut = fullfile(paths.T1.dir,'T1_WM_CSF_sandwich.nii.gz');
     sentence = sprintf('%s/fslmaths %s -mul %s %s',paths.FSL,fileIn1,fileIn2,fileOut);
     [~,result] = system(sentence);
     
     % Using fsl cluster identify the largest contiguous cluster, and save
     % it out as a new mask.
     filein = fullfile(paths.T1.dir,'T1_WM_CSF_sandwich.nii.gz');
     textout = fullfile(paths.T1.dir,'WM_CSF_sandwich_clusters.txt');
     sentence = sprintf('%s/cluster --in=%s --thresh=1 --osize=%s >%s',paths.FSL,filein,filein,textout);
     [~,result]=system(sentence);
     cluster=dlmread(fullfile(paths.T1.dir,'WM_CSF_sandwich_clusters.txt'),'\t',[1 1 1 1]);
     sentence = sprintf('%s/fslmaths %s -thr %d %s',paths.FSL,filein,cluster,filein);
     [~,result]=system(sentence);
     
     % Binarize and invert the single cluster mask.
     fileIn = fullfile(paths.T1.dir,'T1_WM_CSF_sandwich.nii.gz');
     fileOut = fullfile(paths.T1.dir,'T1_WM_CSF_sandwich');
     sentence = sprintf('%s/fslmaths %s -binv %s',paths.FSL,fileIn,fileOut);
     [~,result] = system(sentence);
     
     % Filter the GM mask with obtained CSF_WM sandwich.
     fileIn1 = fullfile(paths.T1.dir,'T1_WM_CSF_sandwich.nii.gz');
     fileIn2 = fullfile(paths.T1.dir,'T1_GM_mask.nii.gz');
     fileOut = fileIn2;
     sentence = sprintf('%s/fslmaths %s -mul %s %s',paths.FSL,fileIn1,fileIn2,fileOut);
     [~,result] = system(sentence);
end

%% Intersect of parcellations with GM
if flags.T1.parc==1
% Gray matter masking of native space parcellations
    counter = 0;
    for k=1:length(parcs.pdir) % for every indicated parcellation
        fileIn = fullfile(paths.T1.dir,strcat('T1_parc_',parcs.plabel(k).name,'.nii.gz'));
        if exist(fileIn,'file') ~= 2
            warning('%s not found. Exiting...',fileIn')
            return
        end
        fprintf('%s parcellation intersection with GM\n',parcs.plabel(k).name) 
        fileOut = fullfile(paths.T1.dir,strcat('T1_parc_',parcs.plabel(k).name,'_dil.nii.gz'));
        % Dilate the parcellation.
        sentence = sprintf('%s/fslmaths %s -dilD %s',paths.FSL,fileIn,fileOut);
        [~,result] = system(sentence);
    
        % Iteratively mask the dilated parcellation with GM.
        fileMul = fullfile(paths.T1.dir,'T1_GM_mask.nii.gz');
        if exist(fileMul,'file') ~= 2
            warning('%s not found. Exiting...',fileMul')
            return 
        end
        % Apply subject GM mask
        fileOut2 = fullfile(paths.T1.dir,strcat('T1_GM_parc_',parcs.plabel(k).name,'.nii.gz'));
        sentence = sprintf('%s/fslmaths %s -mul %s %s',paths.FSL,fileOut,fileMul,fileOut2);
        [~,result] = system(sentence);
        % Dilate and remask to fill GM mask a set number of times
        fileOut3 = fullfile(paths.T1.dir,strcat('T1_GM_parc_',parcs.plabel(k).name,'_dil.nii.gz'));
        for i=1:configs.T1.numDilReMask
            sentence = sprintf('%s/fslmaths %s -dilD %s',paths.FSL,fileOut2,fileOut3);
            [~,result]=system(sentence);
            sentence = sprintf('%s/fslmaths %s -mul %s %s',paths.FSL,fileOut3,fileMul,fileOut2);
            [~,result]=system(sentence);
        end
        % 07.25.2017 EJC Remove the left over dil parcellation images.
        sentence = sprintf('rm %s %s %s',fileOut,fileOut3);
        [~,result]=system(sentence);
    if parcs.pcort(k).true == 1
        counter=counter+1;
        %-------------------------------------------------------------------------%
        % Clean up the cortical parcellation by removing subcortical and
        % cerebellar gray matter.
        if counter == 1
            % Generate inverse subcortical mask to isolate cortical portion of parcellation.
            fileIn = fullfile(paths.T1.dir,'T1_subcort_mask.nii.gz');
            fileOut = fullfile(paths.T1.dir,'T1_subcort_mask_dil.nii.gz');
            fileMas = fullfile(paths.T1.dir,'T1_GM_mask.nii.gz');
            sentence = sprintf('%s/fslmaths %s -dilD %s',paths.FSL,fileIn,fileOut);
            [~,result]=system(sentence);
            sentence = sprintf('%s/fslmaths %s -mas %s %s',paths.FSL,fileOut,fileMas,fileOut);
            [~,result]=system(sentence);
            fileMas2 = fullfile(paths.T1.dir,'T1_subcort_mask_dil_inv.nii.gz');
            sentence = sprintf('%s/fslmaths %s -binv %s',paths.FSL,fileOut,fileMas2);
            [~,result]=system(sentence);
        end
        %---------------------------------------------------------%
        % Apply subcortical inverse to cortical parcellations.
        fileOut = fullfile(paths.T1.dir,strcat('T1_GM_parc_',parcs.plabel(k).name,'.nii.gz'));
        sentence = sprintf('%s/fslmaths %s -mas %s %s',paths.FSL,fileOut,fileMas2,fileOut);
        [~,result]=system(sentence);
        %---------------------------------------------------------%
        % Generate a cerebellum mask using FSL's FIRST.
        if counter == 1
            % inverse transfrom the MNI cerebellum mask
              sprintf('     %s --> T1',parcs.plabel(k).name)
    disp('        unwarp')
    fileRef = fullfile(paths.T1.reg,'T1_dof12.nii.gz');
    fileOut = fullfile(paths.T1.reg,strcat(parcs.plabel(k).name,'_unwarped.nii.gz'));
    sentence = sprintf('%s/applywarp --ref=%s --in=%s --warp=%s --out=%s --interp=nn',...
        paths.FSL,fileRef,fileIn,fileWarpInv,fileOut);
    [~,result] = system(sentence);
            
            
            
        if configs.T1.padfix == 1
            FileIn=fullfile(paths.T1.dir,'T1_fov_denoised.nii');
            FileAFNI=fullfile(paths.T1.dir,'pad5+orig.HEAD');
            sentence=sprintf('%s/3dZeropad -I 5 -prefix %s/pad5 %s; %s/3dAFNItoNIFTI -prefix %s/pad5 %s',...
                paths.AFNI,paths.T1.dir,FileIn,paths.AFNI,paths.T1.dir,FileAFNI);
            [~,result]=system(sentence);
            FileIn = fullfile(paths.T1.dir,'pad5.nii');
            if exist(FileIn,'file')
                [~,result]=system(sprintf('rm %s/pad5+orig*',paths.T1.dir));
            else
                fprintf(2,'zero padding T1_fov_denoised failed. Please debug..\n')
                return
            end
        else
            FileIn=fullfile(paths.T1.dir,'T1_fov_denoised.nii');
        end
        FileRoot=fullfile(paths.T1.dir,'subj_2_std_subc');
        FileMat=fullfile(paths.T1.dir,'subj_2_std_subc_cort.mat');
        FileOut1=fullfile(paths.T1.dir,'L_cerebellum.nii.gz');
        FileOut2=fullfile(paths.T1.dir,'R_cerebellum.nii.gz');
        paths.FSLroot=paths.FSL(1:end-4);
        FileModel1=fullfile(paths.FSLroot,'data/first/models_336_bin/intref_puta/L_Cereb.bmv');
        FileModel2=fullfile(paths.FSLroot,'data/first/models_336_bin/intref_puta/R_Cereb.bmv');
        FileRef1=fullfile(paths.FSLroot,'data/first/models_336_bin/05mm/L_Puta_05mm.bmv');
        FileRef2=fullfile(paths.FSLroot,'data/first/models_336_bin/05mm/R_Puta_05mm.bmv');
        sentence=sprintf('%s/first_flirt %s %s -cort',paths.FSL,FileIn,FileRoot);
        [~,result]=system(sentence);
        sentence=sprintf('%s/run_first -i %s -t %s -o %s -n 40 -m %s -intref %s',paths.FSL,FileIn,FileMat,FileOut1,FileModel1,FileRef1);
        [~,result]=system(sentence);
        sentence=sprintf('%s/run_first -i %s -t %s -o %s -n 40 -m %s -intref %s',paths.FSL,FileIn,FileMat,FileOut2,FileModel2,FileRef2);
        [~,result]=system(sentence);
        % Clean up the edges of the cerebellar mask.
        sentence=sprintf('%s/first_boundary_corr -s %s -i %s -b fast -o %s',paths.FSL,FileOut1,FileIn,FileOut1);
        [~,result]=system(sentence);
        sentence=sprintf('%s/first_boundary_corr -s %s -i %s -b fast -o %s',paths.FSL,FileOut2,FileIn,FileOut2);
        [~,result]=system(sentence);
        % Add the left and right cerebellum masks together.
        FileOut=fullfile(paths.T1.dir,'Cerebellum_bin.nii.gz');
        sentence=sprintf('%s/fslmaths %s -add %s %s',paths.FSL,FileOut1,FileOut2,FileOut);
        [~,result]=system(sentence);
        % remove extra slices if nesessary
        if configs.T1.padfix == 1
            FileAFNI=fullfile(paths.T1.dir,'cut5+orig.HEAD');
            sentence=sprintf('%s/3dZeropad -I -5 -prefix %s/cut5 %s; %s/3dAFNItoNIFTI -prefix %s/cut5 %s',...
                paths.AFNI,paths.T1.dir,FileOut,paths.AFNI,paths.T1.dir,FileAFNI);
            [~,result]=system(sentence);
            FileOut2 = fullfile(paths.T1.dir,'cut5.nii');
            if exist(FileOut2,'file')
                [~,result]=system(sprintf('rm %s/cut5+orig*',paths.T1.dir));
            else
                fprintf(2,'zero padded slice removal in Cerebellum_bin failed. Please debug..\n')
                return
            end
            [~,result]=system(sprintf('mv %s %s',FileOut2,FileOut));
            [~,result]=system(['rm ' FileOut2]);
        end
        %-----------------------------------------------------------------%
        % Fill holes in the mask.
        sentence=sprintf('%s/fslmaths %s -fillh %s',paths.FSL,FileOut,FileOut);
        [~,result]=system(sentence);
        % Invert the cerebellum mask.
        FileInv=fullfile(paths.T1.dir,'Cerebellum_Inv.nii.gz');
        sentence=sprintf('%s/fslmaths %s -binv %s',paths.FSL,FileOut,FileInv);
        [~,result]=system(sentence);
        %-----------------------------------------------------------------%
        % 07.25.2017 EJC Remove intermediates of the clean-up.
        sentence = sprintf('rm %s*;rm %s*;rm %s*;',FileRoot,FileOut1,FileOut2);
        [~,result]=system(sentence);
        sentence = sprintf('rm %s/L_cerebellum_*;rm %s/R_cerebellum_*;',paths.T1.dir,paths.T1.dir);
        [~,result]=system(sentence); 
        if configs.T1.padfix == 1
            [~,result]=system(sprintf('rm %s/pad5.nii',paths.T1.dir));
        end
        end
        %-------------------------------------------------------------------------%    
        % Remove any parcellation contamination of the cerebellum.
        FileIn=fullfile(paths.T1.dir,strcat('T1_GM_parc_',parcs.plabel(k).name,'.nii.gz'));
        FileInv=fullfile(paths.T1.dir,'Cerebellum_Inv.nii.gz');
        sentence=sprintf('%s/fslmaths %s -mas %s %s',paths.FSL,FileIn,FileInv,FileIn);
        [~,result]=system(sentence);
        %-------------------------------------------------------------------------%    
        %% add subcortical fsl parcellation to cortical parcellations
        if configs.T1.addsubcort == 1
            fileSubcort = fullfile(paths.T1.dir,'T1_subcort_seg.nii.gz');
            volParc=MRIread(FileIn);
            MaxID = max(max(max(volParc.vol)));
            volSubcort=MRIread(fileSubcort);
            volSubcort.vol(volSubcort.vol==16)=0;
            %----------------------------------------------------------%
            if parcs.pnodal(k).true == 1 
                ids=unique(volSubcort.vol);
                for s=1:length(ids)
                    if ids(s)>0
                        volSubcort.vol(volSubcort.vol==ids(s))=MaxID+(s-1);
                    end
                end
            elseif parcs.pnodal(k).true == 0
                volSubcort.vol(volSubcort.vol>0)=MaxID+1;
            end
            %----------------------------------------------------------%
            subcorMask=volSubcort.vol > 0;
            volParc.vol(subcorMask)=0;
            volParc.vol=volParc.vol+volSubcort.vol;
            MRIwrite(volParc,FileIn)
        end
%-------------------------------------------------------------------------%
    end
        % 07.26.2017 EJC Dilate the final GM parcellations. 
        % NOTE: These will be used by f_functional_connectivity to bring parcellations into epi space.
        fileOut4 = fullfile(paths.T1.dir,strcat('T1_GM_parc_',parcs.plabel(k).name,'_dil.nii.gz'));
        sentence = sprintf('%s/fslmaths %s -dilD %s',paths.FSL,fileOut2,fileOut4);
        [~,result]=system(sentence);
        if ~isempty(result)
            warning('Dilation of %s parcellation error! See return below for details.',parcs.plabel(k).name);
            disp(result)
        end
    end
end 