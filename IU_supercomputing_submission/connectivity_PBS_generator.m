function connectivity_PBS_generator(subjectlist, batch_set_up, system_sample_set_up, batch_path, pipeline_path, email)
% PBS and matlab wrapper generation script for Karst submissions
%
%  Author:  John D. West - jdwest@iupui.edu  5/24/2018
%  Edited:  Evgeny J. Chumin - echumin@iu.edu 8/12/2019
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
%       -email ->       contact email for notifications of job status.
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

numsubjects = length(subjectfolders);
numPBS = floor(numsubjects/14); % Grabs number of loops needed to generate PBSscripts

% Generate PBS scripts and wrappers for majority of subjects
if numPBS+1>1
    for i=1:numPBS
        subjectsforloop(1:14) = subjectfolders((i*14-14+1):i*14);
        fidpbs = fopen([batch_path '/PBSconnectome_' subjectsforloop(1).name 'to' subjectsforloop(end).name],'w');
        fprintf(fidpbs, '#!/bin/bash\n');
        fprintf(fidpbs, '#PBS -l nodes=1:ppn=16,vmem=32gb,walltime=12:00:00\n');
        fprintf(fidpbs, ['#PBS -M ' email '\n']);
        fprintf(fidpbs, '#PBS -m abe\n');
        fprintf(fidpbs, ['#PBS -N connectome_' subjectsforloop(1).name 'to' subjectsforloop(end).name '\n']);
        fprintf(fidpbs, '#PBS -k oe\n');
        fprintf(fidpbs, '#PBS -j oe\n\n');
        fprintf(fidpbs, 'module unload python\n');
        fprintf(fidpbs, 'module load python/3.6.8\n');
        fprintf(fidpbs, 'module unload fsl\n');
        fprintf(fidpbs, 'module load fsl/6.0.1\n');
        fprintf(fidpbs, 'module unload afni\n');
        fprintf(fidpbs, 'module load afni/18.3.03\n');
        fprintf(fidpbs, 'module unload matlab\n');
        fprintf(fidpbs, 'module load matlab/2019a\n');
        fprintf(fidpbs, 'module load java\n');
        fprintf(fidpbs, 'module load camino\n');
        fprintf(fidpbs, 'module load ants\n');
        fprintf(fidpbs, 'module load camino-trackvis\n\n');
        fprintf(fidpbs, ['cd ' batch_path '\n\n']);        
        fprintf(fidpbs, ['matlab -r PBSmatlab_wrapper_' subjectsforloop(1).name 'to' subjectsforloop(7).name ' &\n\n']);
        fprintf(fidpbs, ['matlab -r PBSmatlab_wrapper_' subjectsforloop(8).name 'to' subjectsforloop(end).name ' &\n\n']);
        fprintf(fidpbs, 'wait\n');
        fclose(fidpbs);
        fidwrap1 = fopen([batch_path '/PBSmatlab_wrapper_' subjectsforloop(1).name 'to' subjectsforloop(7).name '.m'],'w');
        fidwrap2 = fopen([batch_path '/PBSmatlab_wrapper_' subjectsforloop(8).name 'to' subjectsforloop(14).name '.m'],'w');
        
        for j=1:14
             if j<=7
                 
                    fprintf(fidwrap1, ['subjectList(' num2str(j) ',1).name = ''' subjectsforloop(j).name ''';\n']);
                if j==7 
                fprintf(fidwrap1, ['batch_set_up = ''' batch_set_up ''';\n']);
                fprintf(fidwrap1, ['system_sample_set_up = ''' system_sample_set_up ''';\n']);
                fprintf(fidwrap1, ['addpath ' pipeline_path ';\n']);
                fprintf(fidwrap1, 'run_connectivity_pipeline(system_sample_set_up,batch_set_up,subjectList)\n\n');
                end
             else
                
                    fprintf(fidwrap2, ['subjectList(' num2str(j-7) ',1).name = ''' subjectsforloop(j).name ''';\n']);
                if j==14
                fprintf(fidwrap2, ['batch_set_up = ''' batch_set_up ''';\n']);
                fprintf(fidwrap2, ['system_sample_set_up = ''' system_sample_set_up ''';\n']);
                fprintf(fidwrap2, ['addpath ' pipeline_path ';\n']);
                fprintf(fidwrap2, 'run_connectivity_pipeline(system_sample_set_up,batch_set_up,subjectList)\n\n');
                end
            end
        end
        
        fprintf(fidwrap1, 'quit\n');
        fclose(fidwrap1);
        fprintf(fidwrap2, 'quit\n');
        fclose(fidwrap2);
    end
end

%% 
%  Make PBS script and wrappers for remaining subjects if needed

subjectsremain = subjectfolders(numPBS*14+1:end); % grabs last subjects
numsubjectsremain = length(subjectsremain); % finds number of last subjects
thresh = ceil(numsubjectsremain/2); % finds how many subjects to put in each wrapper
if numsubjectsremain>0
    fidpbs = fopen([batch_path '/PBSconnectome_' subjectsremain(1).name 'to' subjectsremain(end).name],'w');
    fprintf(fidpbs, '#!/bin/bash\n');
    fprintf(fidpbs, '#PBS -l nodes=1:ppn=16,vmem=32gb,walltime=12:00:00\n');
    fprintf(fidpbs, ['#PBS -M ' email '\n']);
    fprintf(fidpbs, '#PBS -m abe\n');
    fprintf(fidpbs, ['#PBS -N connectome_' subjectsremain(1).name 'to' subjectsremain(end).name '\n']);
    fprintf(fidpbs, '#PBS -k oe\n');
    fprintf(fidpbs, '#PBS -j oe\n\n');
    fprintf(fidpbs, 'module unload python\n');
    fprintf(fidpbs, 'module load python/3.6.8\n');
    fprintf(fidpbs, 'module unload fsl\n');
    fprintf(fidpbs, 'module load fsl/6.0.1\n');
    fprintf(fidpbs, 'module unload afni\n');
    fprintf(fidpbs, 'module load afni/18.3.03\n');
    fprintf(fidpbs, 'module unload matlab\n');
    fprintf(fidpbs, 'module load matlab/2019a\n');
    fprintf(fidpbs, 'module load java\n');
    fprintf(fidpbs, 'module load camino\n');
    fprintf(fidpbs, 'module load ants\n');
    fprintf(fidpbs, 'module load camino-trackvis\n\n');
    fprintf(fidpbs, ['cd ' batch_path '\n\n']);
    fprintf(fidpbs, ['matlab -r PBSmatlab_wrapper_' subjectsremain(1).name 'to' subjectsremain(thresh).name ' &\n\n']);
    fprintf(fidpbs, ['matlab -r PBSmatlab_wrapper_' subjectsremain(thresh+1).name 'to' subjectsremain(end).name ' &\n\n']);
    fprintf(fidpbs, 'wait\n');
    fclose(fidpbs);
    fidwrap1 = fopen([batch_path '/PBSmatlab_wrapper_' subjectsremain(1).name 'to' subjectsremain(thresh).name '.m'],'w');
    if numsubjectsremain>thresh    
        fidwrap2 = fopen([batch_path '/PBSmatlab_wrapper_' subjectsremain(thresh+1).name 'to' subjectsremain(end).name '.m'],'w');
    end
    for i=1:numsubjectsremain
        if i<=thresh
            
                fprintf(fidwrap1, ['subjectList(' num2str(i) ',1).name = ''' subjectsforloop(i).name ''';\n']);
            if i==thresh
            fprintf(fidwrap1, ['batch_set_up = ''' batch_set_up ''';\n']);
            fprintf(fidwrap1, ['system_sample_set_up = ''' system_sample_set_up ''';\n']);
            fprintf(fidwrap1, ['addpath ' pipeline_path ';\n']);
            fprintf(fidwrap1, 'run_connectivity_pipeline(system_sample_set_up,batch_set_up,subjectList)\n\n');
            end
        elseif numsubjectsremain>thresh
            
                fprintf(fidwrap2, ['subjectList(' num2str(i-thresh) ',1).name = ''' subjectsforloop(i).name ''';\n']);
            if i==numsubjectsremain
            fprintf(fidwrap2, ['batch_set_up = ''' batch_set_up ''';\n']);
            fprintf(fidwrap2, ['system_sample_set_up = ''' system_sample_set_up ''';\n']);
            fprintf(fidwrap2, ['addpath ' pipeline_path ';\n']);
            fprintf(fidwrap2, 'run_connectivity_pipeline(system_sample_set_up,batch_set_up,subjectList)\n\n');
            end
        end
    end
    fprintf(fidwrap1, 'quit\n');
    fclose(fidwrap1);
    if numsubjectsremain>thresh
        fprintf(fidwrap2, 'quit\n');
        fclose(fidwrap2);
    end
end

%%
%  Generate file that will submit all PBS scripts created
pbsscripts = dir([batch_path '/PBSconnectome_*']);
fidpbsrun = fopen([batch_path '/submitPBSscripts.sh'],'w');
for i=1:size(pbsscripts,1)
    fprintf(fidpbsrun,['qsub ' pbsscripts(i).name '\n']);
end
fclose(fidpbsrun);
system(['chmod ug+x ' batch_path '/submitPBSscripts.sh']);