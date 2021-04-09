function [status, result] = aggregate_FC_figures(baseDir, targetDir, EPI, subjects)

if exist(targetDir, 'dir') ~= 7
    mkdir(targetDir);
end
% Aggregate functional connectivity matrices 
    for i = 1:length(subjects)
        source = fullfile(baseDir, subjects(i), EPI, 'GSreg_yes', 'figures', strcat('epi_fig6_',subjects(i),'_yeo_RSN17_org.png'));
        target = fullfile(targetDir, strcat('epi_fig6_',subjects(i),'_yeo_RSN17_org.png'));
        
        sentence = sprintf('cp %s %s', source, target);
        [status, result] = system(sentence);
    end
   
end

