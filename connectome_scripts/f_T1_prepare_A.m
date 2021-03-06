function [paths,flags,configs]=f_T1_prepare_A(paths,flags,configs)
%                            F_T1_PREPARE_A
% T1 precprocessing code that results in denoised/field-of-view cropped T1
% image, generated from provided dicom data. A brain mask as well as a
% brain extracted image are also created.
%
% This function is executed as part of the connectivity pipeline and is not
% mean to run stand-alone.
%
% Contributors:
%   Joaquin Goni, Purdue University
%   Joey Contreras, University Southern California
%   Mario Dzemidzic, Indiana University School of Medicine
%   Evgeny Chumin, Indiana University School of Medicine
%

%% Dicom to NiFTI
if flags.T1.dcm2niix==1
    % set dicom directy and identify file extension
    paths.T1.dcm = fullfile(paths.T1.dir,configs.name.dcmFolder);
    [dcm_ext]=find_dcm_ext(paths.T1.dcm);
    if isempty(dcm_ext)
        warning('No dicom (.IMA or .dcm) images found. Skipping further analysis')
        return
    end
    list_nii = dir(fullfile(paths.T1.dir,'*.nii*'));
    % Remove existing nifti images.
    if size(list_nii,1) >= 1
        sentence = sprintf('rm %s/*.nii*',paths.T1.dir);
        [~,result] = system(sentence); %#ok<*ASGLU>
    end
    % Convert dicom to nifti.
    disp('Converting Dicom-to-nifti')
    fileLog = sprintf('%s/dcm2niix.log',paths.T1.dir);
    sentence = sprintf('%s/connectome_scripts/dcm2niix/dcm2niix -f %s -o %s -v y -x y -b y %s > %s',paths.scripts,configs.name.T1,paths.T1.dir,paths.T1.dcm,fileLog);
    [status,result] = system(sentence);
    if status == 0
        sentence = sprintf('mv %s/%s.nii %s/%s_orig.nii',paths.T1.dir,configs.name.T1,paths.T1.dir,configs.name.T1);
        [~,result] = system(sentence); % Rename T1 to T1_orig
        if configs.T1.useCropped == 1
            sentence = sprintf('gzip -f %s/%s_Crop_1.nii',paths.T1.dir,configs.name.T1);
            [~,result] = system(sentence); % Gzip T1_Crop_1
            sentence = sprintf('mv %s/%s_Crop_1.nii.gz %s/%s.nii.gz',paths.T1.dir,configs.name.T1,paths.T1.dir,configs.name.T1);
            [~,result] = system(sentence); % Rename T1_Crop_1 to T1
        else
            sentence = sprintf('gzip -f %s/%s_orig.nii',paths.T1.dir,configs.name.T1);
            [~,result]=system(sentence);
            sentence = sprintf('mv %s/%s_orig.nii.gz %s/%s.nii.gz',paths.T1.dir,configs.name.T1,paths.T1.dir,configs.name.T1);
            [~,result]=system(sentence);
        end
    else
        warning('Conversion failed.')
        return
    end
end

%% T1 denoiser
        % ONLM denoise T1 data in a fixed intensity range.
if flags.T1.denoiser==1
    fileIn = fullfile(paths.T1.dir,sprintf('%s.nii.gz',configs.name.T1));
    if exist(fileIn,'file')
        disp('Starting T1 denoising')
        T1_fov = MRIread(fileIn);
        vol_denoised = f_denoise_T1(T1_fov.vol);
        T1_fov.vol = vol_denoised;
        MRIwrite(T1_fov,fullfile(paths.T1.dir,'T1_denoised.nii'));
    else
        warning(' %s.nii.gz not found. Exiting...',configs.name.T1)
        return
    end
elseif flags.T1.denoiser==2
    fileIn = fullfile(paths.T1.dir,sprintf('%s.nii.gz',configs.name.T1));
    fileOut = fullfile(paths.T1.dir,'T1_denoised.nii.gz');
    [~,result]=system(sprintf('cp %s %s',fileIn,fileOut));
    disp(result)
    [~,result]=system(sprintf('gunzip -f %s',fileOut));
    disp(result)
    disp('Skipped Denoising. Copied T1 to T1_denoised for further processing.')
else
    disp('Bypassing Denoise section. Input NOT copied to output.')
end

%% FSL ANAT
if flags.T1.anat==1
    paths.T1.anat = fullfile(paths.T1.dir,'T1_denoised.anat');
    disp('Running FSL_ANAT')
    % Remove anat directory if one already exists.
    if exist(paths.T1.anat,'dir')
        sentence = sprintf('rm -r %s',paths.T1.anat);
        [~,result] = system(sentence);
    end
    % Run FSL anat, for bias field correction and subcortical segmentation.
    fileIn1 = fullfile(paths.T1.dir,'T1_denoised.nii');
    if exist(fileIn1,'file')
        % strongbias should be more appropriate for multi-channel coils on 3T scanners.
        % add nocrop option if registration fails
        if configs.T1.bias == 0
            argbias = '--nobias';
        elseif configs.T1.bias == 1
            argbias = '--weakbias';
        elseif configs.T1.bias == 2
            argbias = '--strongbias';
        else
            argbias = '';
        end
        if configs.T1.crop == 0
            argcrop = '--nocrop';
        else
            argcrop = '';
        end   
        arganat = sprintf('%s %s',argbias,argcrop);
        
        sentence = sprintf('%s/fsl_anat --noreg --nononlinreg --noseg --nosubcortseg %s -i %s',paths.FSL,arganat,fileIn1);
        [~,result] = system(sentence);
        fileIn2 = fullfile(paths.T1.anat,'T1_biascorr.nii.gz');
        if exist(fileIn2,'file')
            % Subcortical Segmentation
            outDir = fullfile(paths.T1.anat,'first_results');
            outFiles = [outDir '/T1_first'];
            subcortROI = 'L_Accu,L_Amyg,L_Caud,L_Hipp,L_Pall,L_Puta,L_Thal,R_Accu,R_Amyg,R_Caud,R_Hipp,R_Pall,R_Puta,R_Thal';
            [~,result]=system(sprintf('mkdir %s; %s/run_first_all -i %s -o %s -s %s',outDir,paths.FSL,fileIn2,outFiles,subcortROI));  
            fileSub1 = fullfile(outDir,'T1_first_all_none_firstseg.nii.gz');
            if exist(fileSub1,'file')
                fileSub2 = fullfile(paths.T1.anat,'T1_subcort_seg.nii.gz');
                [~,result]=system(sprintf('cp %s %s',fileSub1,fileSub2));
            else
                warning('FIRST subcortical segmentation output not found! Exiting..')
                return
            end
            % Unzip and copy the biascorrected image to the main derectory.
            fileOut = fullfile(paths.T1.dir,'T1_fov_denoised.nii.gz');
            sentence = sprintf('cp %s %s',fileIn2,fileOut);
            [status,result] = system(sentence);
            if status == 0
                sentence = sprintf('gunzip -f %s',fileOut);
                [status,result] = system(sentence);
                if status == 0
                    disp('Completed FSL_ANAT')
                else
                    warning('Gunzip failed. Check file ownership.') 
                    return
                end
            else
                warning('%s not created. Exiting...',fileOut)
                return
            end
        else
            warning('%s not found. Exiting...',fileIn2)
            return
        end
        % Subcortical masks
        disp('Copying subcortical segmentation.')
        fileIn = fullfile(paths.T1.anat,'T1_subcort_seg.nii.gz');
        fileOut = fullfile(paths.T1.dir,'T1_subcort_seg.nii.gz');
        if exist(fileIn,'file') ~= 2
            fprintf(2,'Subcortical segmentation not found. Exiting...\n')
            return
        end       
        sentence = sprintf('cp %s %s',fileIn,fileOut);
        [~,result] = system(sentence);
    else
        warning('%s not found. Exiting...',fileIn1)
        return
    end
end

%% T1 bet
if flags.T1.bet==1
    disp('Brain Extraction and Masking')
    fileIn = fullfile(paths.T1.dir,'T1_fov_denoised.nii');
%----------    fileOut = fullfile(paths.T1.dir,'T1_brain.nii.gz');
    fileOutroot = fullfile(paths.T1.dir,'T1_');
    switch configs.T1.antsTemplate
        case 'MICCAI'
            fileTemplate = fullfile(paths.scripts,'connectome_scripts/templates/brainmask_templates/MICCAI2012-Multi-Atlas-Challenge-Data/T_template0.nii.gz');
            fileProbability = fullfile(paths.scripts,'connectome_scripts/templates/brainmask_templates/MICCAI2012-Multi-Atlas-Challenge-Data/T_template0_BrainCerebellumProbabilityMask.nii.gz');
            fprintf('%s brain mask template selected\n',configs.T1.antsTemplate)
        case 'NKI'
            fileTemplate = fullfile(paths.scripts,'connectome_scripts/templates/brainmask_templates/NKI/T_template.nii.gz');
            fileProbability = fullfile(paths.scripts,'connectome_scripts/templates/brainmask_templates/NKI/T_template_BrainCerebellumProbabilityMask.nii.gz');
            fprintf('%s brain mask template selected\n',configs.T1.antsTemplate)
        case 'IXI'
            fileTemplate = fullfile(paths.scripts,'connectome_scripts/templates/brainmask_templates/IXI/T_template2.nii.gz');
            fileProbability = fullfile(paths.scripts,'connectome_scripts/templates/brainmask_templates/IXI/T_template_BrainCerebellumProbabilityMask.nii.gz');
            fprintf('%s brain mask template selected\n',configs.T1.antsTemplate)
        case 'bet'
            fprintf('Using bet -f and -g inputs to perform fsl bet with -B option\n')
        otherwise
            fprintf('Unknown brain mask template selection: %s. Exiting...\n',configs.T1.antsTemplate)
    end   
            
    if exist(fileIn, 'file')
        fileIn2 = fullfile(paths.T1.dir,'T1_brain_mask.nii.gz');
        fileOut = fullfile(paths.T1.dir,'T1_brain.nii.gz');
        if strcmp(configs.T1.antsTemplate,'bet') == 1
            sentence = sprintf('%s/bet %s %s -B -m -f %.4f -g %.4f',...
                paths.FSL,fileIn,fileOut,configs.T1.betF,configs.T1.betG);
            [status,result] = system(sentence);
        else
            % ANTS brain extraction
            ANTSlog = fullfile(paths.T1.dir,'ants_bet.log');
            sentence = sprintf('%s/antsBrainExtraction.sh -d 3 -a %s -e %s -m %s -o %s > %s',...
                paths.ANTS,fileIn,fileTemplate,fileProbability,fileOutroot,ANTSlog);
            [status,result]=system(sentence);
            [status,result]=system(sprintf('mv %s/T1_BrainExtractionMask.nii.gz %s',paths.T1.dir,fileIn2));
            [status,result]=system(sprintf('mv %s/T1_BrainExtractionBrain.nii.gz %s',paths.T1.dir,fileOut));
        end
        fileOut2 = fullfile(paths.T1.dir,'T1_brain_mask_filled.nii.gz');
        if status == 0 && exist(fileIn2, 'file')
            % Fill holes in the brain mask.
            sentence = sprintf('%s/fslmaths %s -fillh %s',paths.FSL,fileIn2,fileOut2);
            [status,result] = system(sentence);
            if status == 0 && exist(fileOut2, 'file')
                disp('Bet completed.')
            else
                warning('%s not created. Exiting...',fileOut2)
                return
            end
        else
            warning('%s not found. Exiting...',fileIn2)
            return
        end
    else
        warning('%s not found. Exiting...',fileIn)
        return
    end
end

%% T1 Brain Re-Extract
  % Use the filled brain mask to extract the brain.
if flags.T1.re_extract ==1
    fileIn = fullfile(paths.T1.dir,'T1_fov_denoised.nii');
    fileMask = fullfile(paths.T1.dir,'T1_brain_mask_filled.nii.gz');
    fileOut = fullfile(paths.T1.dir,'T1_brain.nii.gz');
    if exist(fileIn,'file') && exist(fileMask,'file')
        sentence = sprintf('%s/fslmaths %s -mul %s %s',paths.FSL,fileIn,fileMask,fileOut);
        [status,result] = system(sentence);
        if status == 0 && exist(fileOut,'file')
            strdisp = strcat(fileOut,' created.');
            disp(strdisp)
        end
    else
        warning('%s and/or %s not found. Exiting...',fileIn,fileMask)
        return
    end
end

