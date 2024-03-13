function connectivity_slurm_generator(subjectlist, batch_set_up, system_sample_set_up, batch_path, pipeline_path, ppn, vmem, walltime, email,subjperjob)
% PBS and matlab wrapper generation script for Karst submissions
%
%  Author:  John D. West - jdwest@iupui.edu  5/24/2018
%  Edited:  Evgeny J. Chumin - echumin@iu.edu 8/12/2019
%  Edited: Slurm ejc 2022
%
%  This script was written to allow quick generation of multiple PBS
%  scripts and associated matlab wrapper scripts for supercomputing
%  submission for the connectivity pipeline. This will create PBSscripts
%  with will run up to 14 subjects per submission.
%
%  You should edit the above scripts as needed for your situation, but keep
%  the same names. Please only edit the copy of the scripts that you make
%  in your directory.
%
%  INPUTS:
%       -subjectlist -> a path to a structure named subjectList with a 
%                       field .name that contains all IDs of data directory
%                       names.
%       -batch_set_up -> location/name for the batch set up file, containing
%                       pipeline configurations.
%       -system_sample_set_up ->
%                       location/name of the system and sample set up file 
%                       that contains paths to software and data
%                       directories.
%       -batch_path ->  path to directory where you want the PBS jobs
%                       placed.
%       -pipeline_path -> path to IUSM-connectivity-pipeline directory
%       -ppn ->         processes per node
%       -vmem ->        RAM memory
%       -walltime ->    max alloted job runtime
%       -email ->       contact email for notifications of job status.
%       -subjperjob ->  number of subjects to run in each job
%
%  You can find templates of the batch and system set up scripts in the 
%  pipeline directory.
%
%% 
% load subjectlist
load(subjectlist,'subjectList');
subjectfolders=subjectList;

if ~exist(batch_path,'dir')
    mkdir(batch_path)
end

if ~exist('subjperjob','var')
    subjperjob = 7;
end

numsubjects = length(subjectfolders);
numPBS = floor(numsubjects/subjperjob); % Grabs number of loops needed to generate PBSscripts

% Generate PBS scripts and wrappers for majority of subjects
if numPBS+1>1
    for i=1:numPBS
        subjectsforloop(1:subjperjob) = subjectfolders((i*subjperjob-subjperjob+1):i*subjperjob);
        fidpbs = fopen([batch_path '/conn_' subjectsforloop(1).name 'to' subjectsforloop(end).name '.sbatch'],'w');
        fprintf(fidpbs, '#!/bin/bash\n\n');

        fprintf(fidpbs, '#SBATCH -J conn_proc\n');
        fprintf(fidpbs, ['#SBATCH -o ' batch_path '/out_' subjectsforloop(1).name 'to' subjectsforloop(end).name '.txt\n']);
        fprintf(fidpbs, ['#SBATCH -e ' batch_path '/err_' subjectsforloop(1).name 'to' subjectsforloop(end).name '.txt\n\n']);
        fprintf(fidpbs, '#SBATCH -p general\n');
        fprintf(fidpbs, '#SBATCH --mail-type=ALL\n');
        fprintf(fidpbs, ['#SBATCH --mail-user=' email '\n']);
        fprintf(fidpbs, '#SBATCH --nodes=1\n');
        fprintf(fidpbs, ['#SBATCH --ntasks-per-node=' ppn '\n']);
        fprintf(fidpbs, ['#SBATCH --time=' walltime '\n']);
        fprintf(fidpbs, ['#SBATCH --mem=' vmem '\n']);

        fprintf(fidpbs, 'module unload python\n');
        fprintf(fidpbs, 'module load python/3.8.2\n');
        fprintf(fidpbs, 'module unload fsl\n');
        fprintf(fidpbs, 'module load fsl/6.0.5.1\n');
        fprintf(fidpbs, 'module unload afni\n');
        fprintf(fidpbs, 'module load afni/22.0.04\n');
        fprintf(fidpbs, 'module unload matlab\n');
        fprintf(fidpbs, 'module load matlab/2022a\n');
        fprintf(fidpbs, 'module load java\n');
        fprintf(fidpbs, 'module load ants\n');
        fprintf(fidpbs, 'module load mrtrix/3.0\n\n');
        fprintf(fidpbs, ['cd ' batch_path '\n\n']);        
        fprintf(fidpbs, ['matlab -r mtlb_wrapper_' subjectsforloop(1).name(5:end) 'to' subjectsforloop(end).name(5:end) ' &\n\n']);
        fprintf(fidpbs, 'wait\n');
        fclose(fidpbs);
        fidwrap1 = fopen([batch_path '/mtlb_wrapper_' subjectsforloop(1).name(5:end) 'to' subjectsforloop(end).name(5:end) '.m'],'w');
        
        for j=1:subjperjob
             if j<=subjperjob
                 
                    fprintf(fidwrap1, ['subjectList(' num2str(j) ',1).name = ''' subjectsforloop(j).name ''';\n']);
                if j==subjperjob 
                fprintf(fidwrap1, ['batch_set_up = ''' batch_set_up ''';\n']);
                fprintf(fidwrap1, ['system_sample_set_up = ''' system_sample_set_up ''';\n']);
                fprintf(fidwrap1, ['addpath ' pipeline_path ';\n']);
                fprintf(fidwrap1, 'run_connectivity_pipeline(system_sample_set_up,batch_set_up,subjectList)\n\n');
                end
            end
        end
        
        fprintf(fidwrap1, 'quit\n');
        fclose(fidwrap1);
    end
end

%% 
%  Make PBS script and wrappers for remaining subjects if needed

subjectsremain = subjectfolders(numPBS*subjperjob+1:end); % grabs last subjects
numsubjectsremain = length(subjectsremain); % finds number of last subjects
if numsubjectsremain>0
    fidpbs = fopen([batch_path '/conn_' subjectsremain(1).name 'to' subjectsremain(end).name '.sbatch'],'w');
    fprintf(fidpbs, '#!/bin/bash\n\n');

    fprintf(fidpbs, '#SBATCH -J conn_proc\n');
    fprintf(fidpbs, ['#SBATCH -o ' batch_path '/out_' subjectsforloop(1).name 'to' subjectsforloop(end).name '.txt\n']);
    fprintf(fidpbs, ['#SBATCH -e ' batch_path '/err_' subjectsforloop(1).name 'to' subjectsforloop(end).name '.txt\n\n']);
    fprintf(fidpbs, '#SBATCH -p general\n');
    fprintf(fidpbs, '#SBATCH --mail-type=ALL\n');
    fprintf(fidpbs, ['#SBATCH --mail-user=' email '\n']);
    fprintf(fidpbs, '#SBATCH --nodes=1\n');
    fprintf(fidpbs, ['#SBATCH --ntasks-per-node=' ppn '\n']);
    fprintf(fidpbs, ['#SBATCH --time=' walltime '\n']);
    fprintf(fidpbs, ['#SBATCH --mem=' vmem '\n']);

    fprintf(fidpbs, 'module unload python\n');
    fprintf(fidpbs, 'module load python/3.8.2\n');
    fprintf(fidpbs, 'module unload fsl\n');
    fprintf(fidpbs, 'module load fsl/6.0.5.1\n');
    fprintf(fidpbs, 'module unload afni\n');
    fprintf(fidpbs, 'module load afni/22.0.04\n');
    fprintf(fidpbs, 'module unload matlab\n');
    fprintf(fidpbs, 'module load matlab/2022a\n');
    fprintf(fidpbs, 'module load java\n');
    fprintf(fidpbs, 'module load ants\n');
    fprintf(fidpbs, 'module load mrtrix/3.0\n\n');
    fprintf(fidpbs, ['cd ' batch_path '\n\n']);        
    fprintf(fidpbs, ['matlab -r mtlb_wrapper_' subjectsremain(1).name(5:end) 'to' subjectsremain(end).name(5:end) ' &\n\n']);
    fprintf(fidpbs, 'wait\n');
    fclose(fidpbs);
    fidwrap1 = fopen([batch_path '/mtlb_wrapper_' subjectsremain(1).name(5:end) 'to' subjectsremain(numsubjectsremain).name(5:end) '.m'],'w');

    for i=1:numsubjectsremain
        if i<=numsubjectsremain

            fprintf(fidwrap1, ['subjectList(' num2str(i) ',1).name = ''' subjectsremain(i).name ''';\n']);
                if i==numsubjectsremain
                fprintf(fidwrap1, ['batch_set_up = ''' batch_set_up ''';\n']);
                fprintf(fidwrap1, ['system_sample_set_up = ''' system_sample_set_up ''';\n']);
                fprintf(fidwrap1, ['addpath ' pipeline_path ';\n']);
                fprintf(fidwrap1, 'run_connectivity_pipeline(system_sample_set_up,batch_set_up,subjectList)\n\n');
                end
        end
    end
    fprintf(fidwrap1, 'quit\n');
    fclose(fidwrap1);
end

%%  Generate file that will submit all PBS scripts created
sscripts = dir([batch_path '/conn_*.sbatch']);
fidSLURMrun = fopen([batch_path '/submitSLURMscripts.sh'],'w');
for i=1:size(sscripts,1)
    fprintf(fidSLURMrun,['sbatch ' sscripts(i).name '\n']);
end
fclose(fidSLURMrun);
system(['chmod ug+x ' batch_path '/submitSLURMscripts.sh']);