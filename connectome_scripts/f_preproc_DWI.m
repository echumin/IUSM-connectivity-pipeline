function [paths,flags,configs]=f_preproc_DWI(paths,flags,configs,sid)
%                           DWI PREPROCESSING
%   Includes steps starting from dicom inport and goes all the way through
%           generation of scalar maps and anatomical registration. 
%
%   Evgeny Chumin, Indiana University School of Medicine, 2018
%   John West, Indiana University School of Medicine, 2018
%   Mario Dzemidzic, Indiana University School of Medicine, 2018
%%
%
%   JDW edit 03/16/2018 - added *.nii.gz to TOPUP area dir command to avoid grabbing non
%       imaging files which causes subsequent fslmerge to crash - line 132
%   MDZ addition 11/30/2020 - allow two sets of DWI images (e.g., AP and PA)
%
%% DICOM Import
%  DWIdcm(1).dir = ' ';
%  DWIdcm(2).dir = ' ';
%  DWIdcm(1).niifile = '0_DWI';
%  DWIdcm(2).niifile = ' ';
%  
%  if strcmp(configs.name.dcmFolder1,' ') == 0 && strcmp(configs.name.dcmFolder2,' ') == 0
%      nscanmax = 2; % DWI acquired in two phase directions (e.g., AP and PA)
%      DWIdcm(1).dir = fullfile(paths.DWI.dir,configs.name.dcmFolder1);
%      DWIdcm(2).dir = fullfile(paths.DWI.dir,configs.name.dcmFolder2);
%      DWIdcm(1).niifile = '0_DWI_ph1';
%      DWIdcm(2).niifile = '0_DWI_ph2';
%  elseif strcmp(configs.name.dcmFolder,' ') == 0
      nscanmax = 1; % DWI acquired in one phase direction (b0's non-withstanding)
%      DWIdcm(1).dir = fullfile(paths.DWI.dir,configs.name.dcmFolder);
%  end
 %% SKIPPING THIS EDIT FOR KBASE WHERE WE DONT HAVE DICOM
if flags.DWI.dcm2niix == 1
    for nscan=1:nscanmax % 1 or 2 DWI scans
        disp('------------------------')
        disp('0. DICOM to NIfTI Import')
        disp('------------------------')
        
        paths.DWI.DCM= DWIdcm(nscan).dir;
        fileNii = DWIdcm(nscan).niifile;
        fileNiiStar = strcat(fileNii,'*');
        fileNifti = strcat(fileNii,'.nii');
        fileJson = strcat(fileNii,'.json');
        fileBval = strcat(fileNii,'.bval');
        fileBvec = strcat(fileNii,'.bvec');
        
        if length(dir(paths.DWI.DCM))<= 2 %( '.' '..' are first 2 returns)
            warning('No files found in dicom directory. Import terminated.')
            return
        else
            % Remove any existing .nii/.nii.gz images from dicom directories.
            sentence = sprintf('rm -f %s',fullfile(paths.DWI.dir,fileNiiStar));
            [~,result] = system(sentence);
            % Create nifti bvec and bval files.
            sentence = sprintf('%s/connectome_scripts/dcm2niix/dcm2niix -f %s -o %s -v y %s',paths.scripts,fileNii,paths.DWI.dir,paths.DWI.DCM);
            [~,result] = system(sentence);
            % save verbose output
            dlmwrite(fullfile(paths.DWI.dir,'dcm2niix.log'),result,'delimiter','')
            %gzip nifti image
            sentence=sprintf('gzip %s/%s',paths.DWI.dir,fileNifti);
            [~,result] = system(sentence);
        end
        
        % Check if the readout time is consistent with the readout-time
        % contained in json file.
        dcm2niix_json = fullfile(paths.DWI.dir, fileJson);
        if exist(dcm2niix_json, 'file')
            features = get_features_json(dcm2niix_json, false, true);
            if abs(features.TotalReadoutTime - configs.DWI.readout) >= 0.1
                error('Calculated readout time not consistent with readout time provided by dcm2niix')
            end
            if strcmp(features.PhaseEncodingDirection,'j-')
                configs.DWIdcm(nscan).phase = [0 -1 0 configs.DWI.readout];
            elseif strcmp(features.PhaseEncodingDirection,'j')
                configs.DWIdcm(nscan).phase = [0 1 0 configs.DWI.readout];
            else
                warn('PhaseEncodingDirection not implemented or unknown')
                return
            end
            configs.DWIdcm(nscan).SliceTiming = features.SliceTiming;
        end
                        
        disp('----------------------------')
        disp('0.5. Bvec & Bval File Format')
        disp('----------------------------')
        
        if exist(fullfile(paths.DWI.dir,fileBval),'file') && exist(fullfile(paths.DWI.dir,fileBvec),'file') == 0
            warning('Bvec and/or Bval files do not exist. Skipping further analyses')
            return
        else
            % read in Bvals, Bvecs, DWI
            Bval=dlmread(fullfile(paths.DWI.dir,fileBval));
            Bvec=dlmread(fullfile(paths.DWI.dir,fileBvec));
            DWI =MRIread(fullfile(paths.DWI.dir,strcat(fileNifti,'.gz')));
            
            fprintf('%d volumes in dataset. Checking for consistency across Bvec, Bval, and DWI\n',size(DWI.vol,4))
            % check for same number of values as volumes
            if (length(Bval)==size(DWI.vol,4) && length(Bvec)==size(DWI.vol,4)) == 0
                warning('number Bvec and/or Bval values does not match number of volumes. Format Terminated.')
                return
            end
            
            % check for consistency of size after format.
            if (size(Bval,2)==size(DWI.vol,4) && size(Bvec,2)==size(DWI.vol,4)) == 1
                % write out formatted files
                dlmwrite(fullfile(paths.DWI.dir,fileBval),Bval,'delimiter','\t')
                dlmwrite(fullfile(paths.DWI.dir,fileBvec),Bvec,'delimiter','\t')
                disp('Bvec and Bval files written in column format with tab delimiter.')
                disp('----------------------------')
                disp('Dataset Information:        ')
                fprintf('Total number of volumes: %d\n',size(DWI.vol,4))
                fprintf('Number of b0 volumes: %d\n',nnz(Bval<=configs.DWI.b0cut))
                disp('B-values:')
                disp(unique(Bval))
                disp('----------------------------')
            else
                warning('Column formatted Bvec and Bval are not consistent with number of volumes. Terminating.')
                return
            end
        end
    end
    
    switch nscan
        case 1
            disp('Single phase direction')
        case 2
            disp('Two phase directions')
            % create a single nifti file
            fileIn1 = fullfile(paths.DWI.dir,'0_DWI_ph1.nii.gz');
            fileIn2 = fullfile(paths.DWI.dir,'0_DWI_ph2.nii.gz');
            fileOut = fullfile(paths.DWI.dir,'0_DWI');
            if exist(fileIn1,'file') && exist(fileIn2,'file')
                sentence = sprintf('rm -rf %s',fullfile(paths.DWI.dir,'0_DWI.nii*'));
                [~,result] = system(sentence);
                sentence=sprintf('%s/fslmerge -t %s %s %s',paths.FSL,fileOut,fileIn1,fileIn2');
                [~,result]=system(sentence);
            else
                warning('%s or %s not found. Exiting...',fileIn1,fileIn2')
                return
            end
        otherwise
            disp('DWI DICOMS should be in a single or two directories')
            return
    end
end
%% FSL Topup
%% SKIPPING THIS FOR KBASE ; NO OPPOSITE PHASE AVAILABLE
if flags.DWI.topup == 1
    disp('-------------------------')
    disp('1. Topup Field Estimation')
    disp('-------------------------')
    
    % set paths to opposite phase encoded images
    paths.DWI.UNWARP = fullfile(paths.DWI.dir,configs.name.unwarpFolder);
    % remove files from previous run.
        sentence=sprintf('rm %s %s %s',fullfile(paths.DWI.UNWARP,'*.nii.gz'),...
                                        fullfile(paths.DWI.UNWARP,'*log'),...
                                        fullfile(paths.DWI.UNWARP,'*.txt'));
        [~,result]=system(sentence); %#ok<*ASGLU>
    % use dcmPA directory to include opposite phase b0 series (nscanmax=1)
    % but ignore in the elseif statements below if DWI data are in both phase
    % directions (nscanmax=2) and separate b0 series does not exist.
    paths.DWI.dcmPA = fullfile(paths.DWI.UNWARP,configs.name.dcmPA);
    
    if ~exist(paths.DWI.UNWARP,'dir')
        warning('No UNWARP dicom directory found! Skipping topup.')
    elseif nscanmax == 1 && ~exist(paths.DWI.dcmPA,'dir')  
        warning('No dicom directory found within UNWARP! Skipping topup.')
    elseif nscanmax == 1 && length(dir(paths.DWI.dcmPA))<= 2 %( '.' '..' are first 2 returns)
        warning('No files found within UNWARP dicom directory! Skipping topup.')
    else 
        % Extract b0 volumes from dataset
        for n_dwi = 1:nscanmax
            if nscanmax == 1
                dwifile = '0_DWI';
                b0file = 'AP_b0';
                % Dicom import the PA volume
                % remove existing files
                if exist(fullfile(paths.DWI.UNWARP,'PA_b0.nii.gz'))
                    sentence = sprintf('rm -rf %s',fullfile(paths.DWI.UNWARP,'PA_b0.nii.gz'));
                    [~,result] = system(sentence);
                end
                % dicom import
                sentence = sprintf('%s/connectome_scripts/dcm2niix/dcm2niix -f %s -o %s -v y %s',paths.scripts,'PA_b0',paths.DWI.UNWARP,paths.DWI.dcmPA);
                [~,result] = system(sentence);
                % save log file
                dlmwrite(fullfile(paths.DWI.UNWARP,'dcm2niix.log'),result,'delimiter','')
                % gzip output image
                sentence = sprintf('gzip %s/PA_b0.nii',paths.DWI.UNWARP);
                [~,result] = system(sentence);
                
                % Check if the readout time is consistent with the readout-time
                % contained in json file.
                fileJson = strcat('PA_b0','.json');
                dcm2niix_json = fullfile(paths.DWI.UNWARP, fileJson);
                if exist(dcm2niix_json, 'file')
                    features = get_features_json(dcm2niix_json, false, true);
                    if abs(features.TotalReadoutTime - configs.DWI.readout) >= 0.1
                        error('Calculated readout time not consistent with readout time provided by dcm2niix')
                    end
                    if strcmp(features.PhaseEncodingDirection,'j-')
                        configs.DWIdcm(2).phase = [0 -1 0 configs.DWI.readout]; % index 1 is A-P
                    elseif strcmp(features.PhaseEncodingDirection,'j')
                        configs.DWIdcm(2).phase = [0 1 0 configs.DWI.readout];
                    else
                        warn('PhaseEncodingDirection not implemented or unknown')
                        return
                    end
                end
            else
                dwifile = strcat('0_DWI_ph',num2str(n_dwi));
                b0file = strcat('ph',num2str(n_dwi),'_b0_');
            end
            bvalfile = strcat(dwifile,'.bval');
            Bval = dlmread(fullfile(paths.DWI.dir,bvalfile));
            B0_index = find(Bval<=configs.DWI.b0cut); B0_index=B0_index-1; % start at 0
            if isempty(B0_index)
                warning('No b0 volumes identified. Check quality of 0_DWI.bval')
                return
            else
                disp('Identified B0 indices:')
                disp(B0_index)
                dwiniifile = strcat(dwifile,'.nii.gz');
                fileIn = fullfile(paths.DWI.dir,dwiniifile);
                numb0=length(B0_index);
                % Extract B0 images from the 4D series
                for i=1:numb0
                    fileOut = fullfile(paths.DWI.UNWARP,sprintf('%s%d.nii.gz',b0file,B0_index(i)));
                    sentence=sprintf('%s/fslroi %s %s %d 1',paths.FSL,fileIn,fileOut,B0_index(i));
                    [~,result]=system(sentence);
                end
                if flags.DWI.dcm2niix ==0
                dcm2niix_json = fullfile(paths.DWI.dir, '0_DWI.json');
                if exist(dcm2niix_json, 'file')
                    features = get_features_json(dcm2niix_json, false, true);
                    if strcmp(features.PhaseEncodingDirection,'j-')
                        configs.DWIdcm(1).phase = [0 -1 0 configs.DWI.readout];
                    elseif strcmp(features.PhaseEncodingDirection,'j')
                        configs.DWIdcm(1).phase = [0 1 0 configs.DWI.readout];
                    else
                        warn('PhaseEncodingDirection not implemented or unknown')
                        return
                    end
                    configs.DWIdcm(1).SliceTiming = features.SliceTiming;
                end
                end
            end
        end
    end
    % Concatenate AP and PA into a single 4D volume.
    % create a list of AP volume names
    % list all files in unwarp directory
    B0_list=dir([paths.DWI.UNWARP '/*.nii.gz']); %JDWedit - added *.nii.gz to avoid grabbing non image files.
    % remove from list directory and log file
    idx=find(strcmp({B0_list.name},configs.name.dcmPA)==1); B0_list(idx)=[]; %#ok<*FNDSB>
    idx=find(strcmp({B0_list.name},'dcm2niix.log')==1); B0_list(idx)=[];
    % generate file list for fslmerge
    for i=1:length(B0_list)
        fileTemp = fullfile(paths.DWI.UNWARP,B0_list(i).name);
        if i == 1
            filesIn = fileTemp;
        else
            filesIn = strcat(filesIn,{' '},fileTemp);
        end
    end
    % merge into a 4D volume
    fileOut=fullfile(paths.DWI.UNWARP,'All_b0.nii.gz');
    sentence=sprintf('%s/fslmerge -t %s %s',paths.FSL,fileOut,filesIn{1}');
    [~,result]=system(sentence);
    % generate acqparams.txt necessary for topup
    PAcount=length(B0_list)-length(B0_index); %subtract #of AP b0 from total b0
             APline = [0 -1 0 configs.DWI.readout];
             PAline = [0 1 0 configs.DWI.readout];
%     APline = configs.DWIdcm(1).phase;
%     PAline = configs.DWIdcm(2).phase;
    %(stacking rows of AP and PA lines)
    % create AP portion
    for i=1:length(B0_index)
        if i == 1
            acqparams = APline;
        elseif i > 1
            acqparams(end+1,:) = APline; %#ok<*AGROW>
        end
    end
    % add PA portion
    for i=1:PAcount
        acqparams(end+1,:) = PAline;
    end
    % write it out
    dlmwrite(fullfile(paths.DWI.UNWARP,'acqparams.txt'),acqparams,'delimiter',' ')
    
    % Run Topup
    fileIn = fullfile(paths.DWI.UNWARP,'All_b0.nii.gz');
    fileParams = fullfile(paths.DWI.UNWARP,'acqparams.txt');
    fileOutName = fullfile(paths.DWI.UNWARP,'topup_results');
    fileOutField = fullfile(paths.DWI.UNWARP,'topup_field');
    fileOutUnwarped = fullfile(paths.DWI.UNWARP,'topup_unwarped');
    sentence=sprintf('%s/topup --imain=%s --datain=%s --out=%s --fout=%s --iout=%s',...
        paths.FSL,fileIn,fileParams,fileOutName,fileOutField,fileOutUnwarped);
    [~,result]=system(sentence);
end
     
%% FSL EDDY
if flags.DWI.eddyPREP == 1
 %   for nscan=1:nscanmax
    disp('--------------------')
    disp('2.a. EDDY Input Prep')
    disp('--------------------')    
    
    % set paths
  %  paths.DWI.UNWARP = fullfile(paths.DWI.dir,configs.name.unwarpFolder);
 %   if nscanmax == 1
        paths.DWI.EDDY=fullfile(paths.DWI.deriv,'EDDY');
%    elseif nscanmax == 2
 %       paths.DWI.EDDY=fullfile(paths.DWI.dir,strcat('EDDY',num2str(nscan)));
 %   else
  %      disp('Only 1 or 2 DWI series are currently implemented. Exiting...')
  %      return            
  %  end
    % create output directory if one does not exist
    if ~exist(paths.DWI.EDDY,'dir')
        sentence=sprintf('mkdir %s',paths.DWI.EDDY); [~,result]=system(sentence);
    end
    
    % remove any existing files
    sentence=sprintf('rm -fr %s',fullfile(paths.DWI.EDDY,'*'));
    [~,result]=system(sentence);
    
    % Prepare inputs for EDDY
    % Create a B0 mask
%     if exist(paths.DWI.UNWARP,'dir') && exist(fullfile(paths.DWI.UNWARP,'topup_unwarped.nii.gz'),'file')
%             % Inputs if topup was done
%             fileIn = fullfile(paths.DWI.UNWARP,'topup_unwarped.nii.gz');
%             fileMean = fullfile(paths.DWI.EDDY,'meanb0_unwarped.nii.gz');
%     else % if topup distortion not available
%         warning('Topup data not present; Will run EDYY without topup field.')
%         % Extract b0 volumes from dataset
%         if nscanmax == 1
            Bval=dlmread(fullfile(paths.DWI.raw,[sid '_ses-v0_dwi.bval']));
%         elseif nscanmax == 2
%             Bval=dlmread(fullfile(paths.DWI.dir,'0_DWI_ph',num2str(nscan),'.bval'));
%         else
%             disp('Only 1 or 2 DWI series are currently implemented. Exiting...')
%             return
%         end
        B0_index = find(Bval<=configs.DWI.b0cut); B0_index=B0_index-1; % start at 0
        if isempty(B0_index)
            warning('No b0 volumes identified. Check quality of 0_DWI.bval')
            return
        else
            disp('Identified B0 indices:')
            disp(B0_index)
            fileIn = fullfile(paths.DWI.raw,[sid '_ses-v0_dwi.nii']);
            numAP=length(B0_index);
            % Extract B0 images from the 4D series
            for i=1:numAP
                fileOut = fullfile(paths.DWI.EDDY,sprintf('AP_b0_%d.nii.gz',B0_index(i)));
                sentence=sprintf('%s/fslroi %s %s %d 1',paths.FSL,fileIn,fileOut,B0_index(i));
                [~,result]=system(sentence);
            end
        end
        % create a list of AP volume names
        % list all files in EDDY directory
        % Should just be the B0 images
        B0_list=dir(paths.DWI.EDDY);
            % remove from list '.' and '..' 
        B0_list(1:2)=[];
            % generate file list for fslmerge
        for i=1:length(B0_list)
            fileTemp = fullfile(paths.DWI.EDDY,B0_list(i).name);
            if i == 1
                filesIn{1} = fileTemp;
            else
                filesIn = strcat(filesIn,{' '},fileTemp);
            end
        end
            % merge into a 4D volume
        fileOut=fullfile(paths.DWI.EDDY,'all_b0_raw.nii.gz');
        sentence=sprintf('%s/fslmerge -t %s %s',paths.FSL,fileOut,filesIn{1});
        [~,result]=system(sentence);
        % Inputs if topup was not done.
        fileIn = fullfile(paths.DWI.EDDY,'all_b0_raw.nii.gz');
        fileMean = fullfile(paths.DWI.EDDY,'meanb0.nii.gz');
%     end
        
    % generate mean B0 iamge
    sentence = sprintf('%s/fslmaths %s -Tmean %s',...
        paths.FSL,fileIn,fileMean);
    [~,result]=system(sentence);
    % run FSL brain extration to get B0 brain mask
    fileBrain = fullfile(paths.DWI.EDDY,'b0_brain.nii.gz');
    sentence = sprintf('%s/bet %s %s -f %.2f -m',paths.FSL,fileMean,fileBrain,configs.DWI.EDDYf);
    [~,result]=system(sentence);  
    
   % Find location of b0 volumes in dataset
%     if nscanmax == 1
        Bval=dlmread(fullfile(paths.DWI.raw,[sid '_ses-v0_dwi.bval']));
%     elseif nscanmax == 2
%         Bval=dlmread(fullfile(paths.DWI.dir,strcat('0_DWI_ph',num2str(nscan),'.bval')));
%     else
%         disp('Only 1 or 2 DWI series are currently implemented. Exiting...')
%         return
%     end
    B0_index = find(Bval<=configs.DWI.b0cut); %#ok<*EFIND>
    if isempty(B0_index)
        warning('No b0 volumes identified. Check quality of 0_DWI.bval')
        return
    end

    % Acquisition parameter file
    % EDDY only cares about phase encoding and readout of the data
    % being put in; so unless you DWI series contains both AP and PA in
    % one 4D image, only one line is needed.
    APline = [0 -1 0 .03];%!!! 
    % PAline = [0 1 0 configs.DWI.readout];
    %APline = configs.DWIdcm(1).phase;
    for i=1:length(B0_index)
        if i == 1
            acqparams = APline;
        elseif i > 1
            acqparams(end+1,:) = APline; %#ok<*AGROW>
        end
    end
        % Write out the acqparams file
    dlmwrite(fullfile(paths.DWI.EDDY,'acqparams.txt'),acqparams,'delimiter',' ')
    
    % Index file
    % read in DWI data and find number of volumes
%     if nscanmax == 1
        DWI =MRIread(fullfile(paths.DWI.raw,[sid '_ses-v0_dwi.nii']));
%     elseif nscanmax == 2
%         DWI =MRIread(fullfile(paths.DWI.dir,strcat('0_DWI_ph',num2str(nscan),'.nii.gz')));
%     else
%         disp('Only 1 or 2 DWI series are currently implemented. Exiting...')
%         return
%     end

    numVols=size(DWI.vol,4);
    % Generate index file of ones
    Index=ones(numVols,1);
    % Preserve temporal information about B0 location
    for i=1:length(B0_index)
        if B0_index(i)==1 % do nothing; the index is a column of ones
        else
            % for every subsequent B0 the volume index increases. This
            % provides temporal information about location of B0 volumes.
            Index(B0_index(i):end,1)=i;
        end
    end
    % Write out the index file
    dlmwrite(fullfile(paths.DWI.EDDY,'index.txt'),Index,'delimiter',' ')
   % end
end
if flags.DWI.eddyRUN == 1
%    for nscan=1:nscanmax
    disp('-------------')
    disp('2.b. Run EDDY')
    disp('-------------') 
    % set paths
%     paths.DWI.UNWARP = fullfile(paths.DWI.dir,configs.name.unwarpFolder);
%     if nscanmax == 1
        paths.DWI.EDDY=fullfile(paths.DWI.deriv,'EDDY');
%     elseif nscanmax == 2
%         paths.DWI.EDDY=fullfile(paths.DWI.dir,strcat('EDDY',num2str(nscan)));
%     else
%         disp('Only 1 or 2 DWI series are currently implemented. Exiting...')
%         return            
%     end
    
    % State EDDY inputs
%     if nscanmax == 1
        fileIn = fullfile(paths.DWI.raw,[sid '_ses-v0_dwi.nii']);
        fileBvec = fullfile(paths.DWI.raw,[sid '_ses-v0_dwi.bvec']);
        fileBval = fullfile(paths.DWI.raw,[sid '_ses-v0_dwi.bval']);
        fileJson = fullfile(paths.DWI.raw,[sid '_ses-v0_dwi.json']);
%     elseif nscanmax == 2
%         fileIn = fullfile(paths.DWI.dir,strcat('0_DWI_ph',num2str(nscan),'.nii.gz'));
%         fileBvec = fullfile(paths.DWI.dir,strcat('0_DWI_ph',num2str(nscan),'.bvec'));
%         fileBval = fullfile(paths.DWI.dir,strcat('0_DWI_ph',num2str(nscan),'.bval'));
%         fileJson = fullfile(paths.DWI.dir,strcat('0_DWI_ph',num2str(nscan),'.json'));
%     else
%         disp('Only 1 or 2 DWI series are currently implemented. Exiting...')
%         return            
%     end
    fileMask = fullfile(paths.DWI.EDDY, 'b0_brain_mask.nii.gz');
    
%     if exist(paths.DWI.UNWARP,'dir') && exist(fullfile(paths.DWI.UNWARP,'topup_results_movpar.txt'),'file')
%         fileTopup = fullfile(paths.DWI.UNWARP,'topup_results'); % input only if topup was done.
%     end
    fileIndex = fullfile(paths.DWI.EDDY,'index.txt');
    fileAcqp = fullfile(paths.DWI.EDDY,'acqparams.txt');
    fileOut = fullfile(paths.DWI.EDDY,'eddy_output');
        
    tic %star timer
    if configs.DWI.repolON == 1 % Remove and interpolate outlier slices
        % By default, an outlier is a slice whose average intensity is at
        % least 4 standard deviations lower than what is expected by the
        % Gaussian Process Prediction within EDDY.
%         if exist(paths.DWI.UNWARP,'dir') && exist(fullfile(paths.DWI.UNWARP,'topup_results_fieldcoef.nii.gz'),'file')
%             if configs.DWI.MBjson == 1
%                 sentence = sprintf('LD_LIBRARY_PATH= %s/eddy_openmp --imain=%s --mask=%s --bvecs=%s --bvals=%s --topup=%s --index=%s --acqp=%s --repol --json=%s --out=%s',...
%                     paths.FSL,fileIn,fileMask,fileBvec,fileBval,fileTopup,fileIndex,fileAcqp,fileJson,fileOut);
%             else
%                 sentence = sprintf('LD_LIBRARY_PATH= %s/eddy_openmp --imain=%s --mask=%s --bvecs=%s --bvals=%s --topup=%s --index=%s --acqp=%s --repol --out=%s',...
%                     paths.FSL,fileIn,fileMask,fileBvec,fileBval,fileTopup,fileIndex,fileAcqp,fileOut);
%             end
%         else % no topup field available
            if configs.DWI.MBjson == 1
                sentence = sprintf('LD_LIBRARY_PATH= %s/eddy_openmp --imain=%s --mask=%s --bvecs=%s --bvals=%s --index=%s --acqp=%s --repol --json=%s --out=%s',...
                    paths.FSL,fileIn,fileMask,fileBvec,fileBval,fileIndex,fileAcqp,fileJson,fileOut);
            else
                sentence = sprintf('LD_LIBRARY_PATH= %s/eddy_openmp --imain=%s --mask=%s --bvecs=%s --bvals=%s --index=%s --acqp=%s --repol --out=%s',...
                    paths.FSL,fileIn,fileMask,fileBvec,fileBval,fileIndex,fileAcqp,fileOut);
            end
%         end
        [~,result]=system(sentence);
        disp(result)
    else % no repol
%         if exist(paths.DWI.UNWARP,'dir') && exist(fullfile(paths.DWI.UNWARP,'topup_results_fieldcoef.nii.gz'),'file')
%             sentence = sprintf('LD_LIBRARY_PATH= %s/eddy_openmp --imain=%s --mask=%s --bvecs=%s --bvals=%s --topup=%s --index=%s --acqp=%s --out=%s',...
%                 paths.FSL,fileIn,fileMask,fileBvec,fileBval,fileTopup,fileIndex,fileAcqp,fileOut);
%         else% no topup field available
            sentence = sprintf('LD_LIBRARY_PATH= %s/eddy_openmp --imain=%s --mask=%s --bvecs=%s --bvals=%s --index=%s --acqp=%s --out=%s',...
                paths.FSL,fileIn,fileMask,fileBvec,fileBval,fileIndex,fileAcqp,fileOut);
%         end
        [~,result]=system(sentence);
        disp(result)
    end
    rtime=(toc/60); % elapsed time in minutes
    fprintf('EDDY runtime: %2f minutes\n',rtime)

    % For QC purpoces this created a difference (Delta image) between raw
    % and EDDY corrected diffusion data.
    DWI =MRIread(fullfile(paths.DWI.raw,[sid '_ses-v0_dwi.nii']));
    corrDWI=MRIread(sprintf('%s.nii.gz',fileOut));
    corrDWI.vol=corrDWI.vol - DWI.vol;
    MRIwrite(corrDWI,fullfile(paths.DWI.EDDY,'delta_DWI.nii.gz'))
%     if nscan == nscanmax
%         clear DWI corrDWI
%     end
%     end
end

%% DTIfit
if flags.DWI.DTIfit == 1
%    for nscan=1:nscanmax
        disp('---------------------------')
        disp('3. Fitting Diffusion Tensor')
        disp('---------------------------')
        
        % set paths
%        if nscanmax == 1
            paths.DWI.EDDY=fullfile(paths.DWI.deriv,'EDDY');
            paths.DWI.DTIfit=fullfile(paths.DWI.deriv,'DTIfit');
%         elseif nscanmax == 2
%             paths.DWI.EDDY=fullfile(paths.DWI.dir,strcat('EDDY',num2str(nscan)));
%             paths.DWI.DTIfit=fullfile(paths.DWI.dir,strcat('DTIfit',num2str(nscan)));
%         else
%             disp('Only 1 or 2 DWI series are currently implemented. Exiting...')
%             return
%         end

        % create output directory if one does not exist
        if ~exist(paths.DWI.DTIfit,'dir')
            sentence=sprintf('mkdir %s',paths.DWI.DTIfit); [~,result]=system(sentence);
        end
        
        % remove any existing files
        sentence=sprintf('rm -fr %s',fullfile(paths.DWI.DTIfit,'*'));
        [~,result]=system(sentence);
        
        % Prepare inputs for DTIfit
        % DWI data in (from EDDY)
        fileDWI=fullfile(paths.DWI.EDDY,'eddy_output.nii.gz');
        
        % Format the Bval file (row format)
%         if nscanmax == 1 
            Bval=dlmread(fullfile(paths.DWI.raw,[sid '_ses-v0_dwi.bval']));
%         elseif nscanmax == 2
%             Bval=dlmread(fullfile(paths.DWI.dir,strcat('0_DWI_ph',num2str(nscan),'.bval')));
%         else
%             disp('Only 1 or 2 DWI series are currently implemented. Exiting...')
%             return
%         end
        if size(Bval,2)==1
            Bval=Bval';
        end
        dlmwrite(fullfile(paths.DWI.DTIfit,'3_DWI.bval'),Bval,'delimiter','\t')
        fileBval=fullfile(paths.DWI.DTIfit,'3_DWI.bval');
        
        % Rotated Bvec from EDDY will be used here.
        fileBvec=fullfile(paths.DWI.EDDY,'eddy_output.eddy_rotated_bvecs');
        
        % Create a brain mask of EDDY corrected data
        b0_1st=find(Bval==0); b0_1st=b0_1st(1)-1; % fsl index of 1st b0 volume
        fileb0=fullfile(paths.DWI.DTIfit,'b0_1st.nii.gz'); % file out b0
        sentence=sprintf('%s/fslroi %s %s %d 1',paths.FSL,fileDWI,fileb0,b0_1st);
        [~,result]=system(sentence); % extract b0 into 3D volume
        sentence = sprintf('%s/bet %s %s -f %.2f -m',paths.FSL,fileb0,fileb0,configs.DWI.DTIfitf);
        [~,result]=system(sentence); % brain extraction of b0
        fileMask=fullfile(paths.DWI.DTIfit,'b0_1st_mask.nii.gz');
        
        % output base name
        fileOut=fullfile(paths.DWI.DTIfit,'3_DWI');
        
        % run DTIfit
        sentence=sprintf('%s/dtifit -k %s -o %s -m %s -r %s -b %s --save_tensor -V',...
            paths.FSL,fileDWI,fileOut,fileMask,fileBvec,fileBval);
        [~,result]=system(sentence);
        
        % save verbose output
        dlmwrite(fullfile(paths.DWI.DTIfit,'dtifit.log'),result,'delimiter','')
    %end
end

% Preproc DWI_A is done.
disp('DWI_A is done.')
disp('QC recommendations:')
disp('1. Check topup_field.nii.gz in UNWARP')
disp('2. Check delta_DWI.nii.gz in EDDY')
disp('2b. If eddy_correct was ran check eddy_output also')
disp('3. Check 3_DWI_V1.nii.gz in DTIfit, with FSLeyes')

end
