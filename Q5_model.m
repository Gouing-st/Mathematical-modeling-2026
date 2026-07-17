%% ========================================================================
%  Q5  Multi-Dimensional Effectiveness Evaluation & Phased Operation Plan
%  Inputs : Q1 site, Q2 growth & equipment, Q3 tier targets, Q4 cash flow
%  Outputs: tier evolution (Leslie-type cohort model), 3 composite indices
%           (entropy-weighted), 3-phase plan, 6 journal figures
%  MATLAB R2025b
%  ========================================================================
clear; clc; close all;
rng(0);

outdir = fullfile(pwd,'Q5_figs');
if ~exist(outdir,'dir'); mkdir(outdir); end

%% ---------- journal style ----------
set(0,'DefaultAxesFontName','Arial','DefaultTextFontName','Arial');
set(0,'DefaultAxesFontSize',11,'DefaultAxesLineWidth',1.0);
set(0,'DefaultLineLineWidth',1.8);
col.blue=[0.00 0.45 0.74]; col.orange=[0.85 0.33 0.10];
col.green=[0.20 0.63 0.17]; col.purple=[0.49 0.18 0.56];
col.grey=[0.50 0.50 0.50]; col.red=[0.80 0.14 0.14];
col.teal=[0.00 0.60 0.56]; col.gold=[0.80 0.68 0.20];
tier_col = [col.green; col.blue; col.teal; col.orange; col.red];

%% ========================================================================
%  1.  INPUTS (Q1-Q4 final results)
%  ========================================================================
K=1000; N0=100; r_log=0.50; A_log=(K-N0)/N0;
Tspan=0:10;
N = K./(1+A_log.*exp(-r_log.*Tspan));
dN = [N0, diff(N)];              % new entrants each year (all -> Seedling)

n_hw=341; n_comp=488;
a_d=0.40; b_d=0.65;
D_hw=a_d*N; D_comp=b_d*N;
util_hw = min(D_hw/n_hw,1);
util_comp = min(D_comp/n_comp,1);

t_inflect = log(A_log)/r_log;     % 4.39
t_sat     = log(9*A_log)/r_log;   % 8.79

CAPEX = 2799;                     % Q4, wan CNY
static_cumCF10 = -154.3;          % Q4 static cum CF at year 10
first_CF_pos_year = 3;            % Q4 first positive-CF year

fprintf('============================================================\n');
fprintf(' Q5  Multi-Dimensional Evaluation & Phased Operation Plan\n');
fprintf('============================================================\n');
fprintf(' Inflection t=%.2f yr | Saturation(0.9K) t=%.2f yr\n',t_inflect,t_sat);

%% ========================================================================
%  2.  ENTERPRISE-TIER EVOLUTION MODEL (Leslie-type cohort-flow model)
%  ========================================================================
tier_names = {'Seedling','Micro','Quality','Potential Unicorn','Flagship'};

% graduation matrix G: row=current tier, col=next-year tier (no skip)
G = [0.55 0.45 0.00 0.00 0.00;
     0.00 0.60 0.40 0.00 0.00;
     0.00 0.00 0.65 0.35 0.00;
     0.00 0.00 0.00 0.70 0.30;
     0.00 0.00 0.00 0.00 1.00];

fprintf('\n--- Graduation matrix G ---\n');
for i=1:5
    fprintf('  %-18s : [%.2f %.2f %.2f %.2f %.2f]\n',tier_names{i},G(i,:));
end

X = zeros(11,5);
X(1,:) = [N0,0,0,0,0];
for t=2:11
    X(t,:) = X(t-1,:)*G;
    X(t,1) = X(t,1) + dN(t);
end
pi_tier = X ./ sum(X,2);

fprintf('\n--- Tier headcount X(t) ---\n');
fprintf(' %-4s',''); for i=1:5; fprintf('%-11s',tier_names{i}(1:min(8,end))); end; fprintf('\n');
for t=1:11
    fprintf(' t=%-2d',Tspan(t));
    for i=1:5; fprintf('%-11.1f',X(t,i)); end
    fprintf('\n');
end

target = [0.12,0.25,0.30,0.23,0.10];   % Q3 assumed maturity shares
fprintf('\n--- Validation vs Q3 target maturity shares ---\n');
fprintf('  Model  yr10: '); fprintf('%.3f ',pi_tier(11,:)); fprintf('\n');
fprintf('  Q3 target  : '); fprintf('%.3f ',target); fprintf('\n');
fprintf('  Deviation  : '); fprintf('%+.3f ',pi_tier(11,:)-target); fprintf('\n');

% Graduated-Progress Index GPI(t) in [0,1]
tier_w = 1:5;
GPI = (pi_tier*tier_w' - 1)/(5-1);
fprintf('\n--- Graduated Progress Index GPI(t) ---\n');
for t=1:11
    fprintf('  t=%-2d GPI=%.3f\n',Tspan(t),GPI(t));
end

%% ========================================================================
%  3.  THREE COMPOSITE INDICES (entropy weighting, consistent w/ Q1)
%  ========================================================================
fprintf('\n--- Composite indices (entropy-weighted, 10-yr samples) ---\n');

adv_tier_share = pi_tier(:,4)+pi_tier(:,5);          % potential+flagship unicorn
base_tier_share = pi_tier(:,1)+pi_tier(:,2);         % seedling+micro
occ_rate = N'/K;

M_innov = [util_hw(2:11)', util_comp(2:11)', adv_tier_share(2:11)];
w_innov = entropy_w(M_innov);
Innov_idx = M_innov*w_innov;

M_talent = [occ_rate(2:11), base_tier_share(2:11)];
w_talent = entropy_w(M_talent);
Talent_idx = M_talent*w_talent;

Cultivation_idx = GPI(2:11);

fprintf('  Innovation index weights (hw_util, comp_util, adv_tier): [%.3f %.3f %.3f]\n',w_innov);
fprintf('  Talent index weights (occupancy, base_tier)            : [%.3f %.3f]\n',w_talent);

%% ========================================================================
%  4.  THREE-PHASE PLAN (boundaries from real computed milestones)
%  ========================================================================
fprintf('\n--- Three-phase plan ---\n');
fprintf(' Phase 1 Construction   : yr 0\n');
fprintf('   CAPEX=%.0f wan, %d HW sets, %d compute nodes, 5-floor build-out\n',CAPEX,n_hw,n_comp);
fprintf(' Phase 2 Incubation-Ops : yr 1-%d (up to 0.9K saturation)\n',ceil(t_sat));
fprintf('   Occupancy 10%%->%.0f%%, GPI %.3f->%.3f, Innov idx %.3f->%.3f, CF turns +ve at yr%d\n',...
        occ_rate(9)*100,GPI(2),GPI(9),Innov_idx(1),Innov_idx(8),first_CF_pos_year);
fprintf(' Phase 3 Mature Dev     : yr %d onward\n',ceil(t_sat));
fprintf('   Occupancy stabilises >90%%, GPI reaches %.3f, static CF gap narrows to %.1f wan by yr10\n',...
        GPI(11),static_cumCF10);

%% ========================================================================
%  5.  FIGURES
%  ========================================================================

% ---- FIG 1: tier headcount stacked area (evolution) ----
f1=figure('Color','w','Position',[60 60 800 480]);
ax=axes(f1); hold(ax,'on'); box(ax,'on'); grid(ax,'on'); ax.GridAlpha=0.12;
ha=area(ax,Tspan,X,'LineStyle','none');
for i=1:5; ha(i).FaceColor=tier_col(i,:); ha(i).FaceAlpha=0.88; end
yline(ax,K,'--k','LineWidth',1.1,'Label','Capacity K','FontSize',9);
xlabel(ax,'Year'); ylabel(ax,'Headcount (persons)');
title(ax,'Enterprise Tier Evolution (Cohort-Flow Model)','FontWeight','bold');
legend(ax,tier_names,'Location','northwest','Box','off','FontSize',9);
xlim(ax,[0 10]); ylim(ax,[0 K*1.08]);
exportgraphics(f1,fullfile(outdir,'Fig1_tier_evolution.png'),'Resolution',300);

% ---- FIG 2: tier share vs Q3 target (yr10 validation bar) ----
f2=figure('Color','w','Position',[60 60 720 480]);
ax=axes(f2); hold(ax,'on'); box(ax,'on'); grid(ax,'on'); ax.GridAlpha=0.12;
bw=0.35; xb=1:5;
bar(ax,xb-bw/2,pi_tier(11,:)*100,bw,'FaceColor',col.blue,'EdgeColor','none');
bar(ax,xb+bw/2,target*100,bw,'FaceColor',col.grey,'EdgeColor','none');
set(ax,'XTick',xb,'XTickLabel',tier_names);
xtickangle(ax,20);
ylabel(ax,'Share (%)');
title(ax,'Year-10 Tier Composition: Model vs Q3 Target','FontWeight','bold');
legend(ax,{'Cohort-flow model (yr10)','Q3 static target'},'Location','northeast',...
       'Box','off','FontSize',9);
for i=1:5
    text(ax,xb(i)-bw/2,pi_tier(11,i)*100+1,sprintf('%.1f',pi_tier(11,i)*100),...
         'HorizontalAlignment','center','FontSize',8);
    text(ax,xb(i)+bw/2,target(i)*100+1,sprintf('%.0f',target(i)*100),...
         'HorizontalAlignment','center','FontSize',8);
end
exportgraphics(f2,fullfile(outdir,'Fig2_validation.png'),'Resolution',300);

% ---- FIG 3: three composite indices over time ----
f3=figure('Color','w','Position',[60 60 780 480]);
ax=axes(f3); hold(ax,'on'); box(ax,'on'); grid(ax,'on'); ax.GridAlpha=0.12;
plot(ax,Tspan(2:11),Innov_idx,'-o','Color',col.blue,'MarkerFaceColor',col.blue,...
     'MarkerSize',6,'MarkerEdgeColor','w');
plot(ax,Tspan(2:11),Talent_idx,'-s','Color',col.orange,'MarkerFaceColor',col.orange,...
     'MarkerSize',6,'MarkerEdgeColor','w');
plot(ax,Tspan(2:11),Cultivation_idx,'-^','Color',col.green,'MarkerFaceColor',col.green,...
     'MarkerSize',6,'MarkerEdgeColor','w');
xlabel(ax,'Year'); ylabel(ax,'Index value (0-1)');
title(ax,'Three Core Composite Indices','FontWeight','bold');
legend(ax,{'Innovation Development','Talent Vitality','Tier Cultivation (GPI)'},...
       'Location','northwest','Box','off','FontSize',9);
xlim(ax,[1 10]); ylim(ax,[0 1]);
exportgraphics(f3,fullfile(outdir,'Fig3_three_indices.png'),'Resolution',300);

% ---- FIG 4: GPI trajectory with phase shading ----
f4=figure('Color','w','Position',[60 60 800 480]);
ax=axes(f4); hold(ax,'on'); box(ax,'on'); grid(ax,'on'); ax.GridAlpha=0.12;
patch(ax,[0 0.3 0.3 0],[0 0 1 1],col.grey,'FaceAlpha',0.12,'EdgeColor','none');
patch(ax,[0.3 t_sat t_sat 0.3],[0 0 1 1],col.blue,'FaceAlpha',0.08,'EdgeColor','none');
patch(ax,[t_sat 10 10 t_sat],[0 0 1 1],col.green,'FaceAlpha',0.10,'EdgeColor','none');
plot(ax,Tspan,GPI,'-o','Color',col.purple,'MarkerFaceColor',col.purple,...
     'MarkerSize',6,'MarkerEdgeColor','w','LineWidth',2.2);
xline(ax,0.3,':','Color',col.grey,'LineWidth',1);
xline(ax,t_sat,':','Color',col.grey,'LineWidth',1);
text(ax,0.05,0.92,'Phase 1','FontSize',9,'FontWeight','bold','Color',col.grey);
text(ax,3.5,0.92,'Phase 2: Incubation-Operation','FontSize',9,'FontWeight','bold','Color',col.blue);
text(ax,t_sat+0.2,0.92,'Phase 3: Mature','FontSize',9,'FontWeight','bold','Color',col.green);
xlabel(ax,'Year'); ylabel(ax,'GPI (Graduated Progress Index)');
title(ax,'Tier Cultivation Index with Three-Phase Boundaries','FontWeight','bold');
xlim(ax,[0 10]); ylim(ax,[0 1]);
exportgraphics(f4,fullfile(outdir,'Fig4_GPI_phases.png'),'Resolution',300);

% ---- FIG 5: radar-style comparison at 3 phase checkpoints ----
f5=figure('Color','w','Position',[60 60 620 560]);
ax=axes(f5); hold(ax,'on'); axis(ax,'equal'); axis(ax,'off');
title(ax,'Three-Index Radar: Phase Checkpoints','FontWeight','bold','Position',[0 1.35 0]);
checkpoints = [2, ceil(t_sat), 10];    % representative years for phase2-start, phase2-end/phase3-start, phase3-end
cp_labels = {sprintf('Yr%d (early)',checkpoints(1)),...
             sprintf('Yr%d (saturation)',checkpoints(2)),...
             sprintf('Yr%d (mature)',checkpoints(3))};
cp_colors = [col.orange; col.blue; col.green];
angles = linspace(0,2*pi,4); angles(end)=[];   % 3 axes
labels3 = {'Innovation','Talent','Cultivation'};
% draw axis grid
for r = [0.25 0.5 0.75 1.0]
    xx = r*cos(angles+pi/2); yy = r*sin(angles+pi/2);
    plot(ax,[xx xx(1)],[yy yy(1)],'-','Color',[0.85 0.85 0.85],'LineWidth',0.8);
end
for k=1:3
    plot(ax,[0 cos(angles(k)+pi/2)],[0 sin(angles(k)+pi/2)],'-','Color',[0.85 0.85 0.85]);
    text(ax,1.18*cos(angles(k)+pi/2),1.18*sin(angles(k)+pi/2),labels3{k},...
         'HorizontalAlignment','center','FontSize',10,'FontWeight','bold');
end
for c = 1:3
    yr = checkpoints(c); idx = yr; % index into 1..10 arrays (Innov_idx etc are yr1..10)
    vals = [Innov_idx(idx), Talent_idx(idx), Cultivation_idx(idx)];
    xx = vals.*cos(angles+pi/2); yy = vals.*sin(angles+pi/2);
    plot(ax,[xx xx(1)],[yy yy(1)],'-o','Color',cp_colors(c,:),'LineWidth',2,...
         'MarkerFaceColor',cp_colors(c,:),'MarkerEdgeColor','w','MarkerSize',6);
    patch(ax,xx,yy,cp_colors(c,:),'FaceAlpha',0.10,'EdgeColor','none');
end
legend(ax,cp_labels,'Location','southoutside','Box','off','FontSize',9,'Orientation','horizontal');
xlim(ax,[-1.4 1.4]); ylim(ax,[-1.4 1.5]);
exportgraphics(f5,fullfile(outdir,'Fig5_radar.png'),'Resolution',300);

% ---- FIG 6: implementation roadmap (schematic timeline) ----
f6=figure('Color','w','Position',[60 60 940 500]);
ax=axes(f6); hold(ax,'on');
set(ax,'XLim',[0 10],'YLim',[0 6],'XTick',0:10,'YTick',[],'Box','off');
title(ax,'Q5 Three-Phase Implementation Roadmap','FontWeight','bold','FontSize',14);
xlabel(ax,'Year');

% phase bands
patch(ax,[0 0.3 0.3 0],[1 1 5 5],col.grey,'FaceAlpha',0.15,'EdgeColor','none');
patch(ax,[0.3 t_sat t_sat 0.3],[1 1 5 5],col.blue,'FaceAlpha',0.10,'EdgeColor','none');
patch(ax,[t_sat 10 10 t_sat],[1 1 5 5],col.green,'FaceAlpha',0.12,'EdgeColor','none');

text(ax,0.15,4.6,'PHASE 1','FontSize',10,'FontWeight','bold','Color',col.grey,'Rotation',90,'HorizontalAlignment','center');
text(ax,(0.3+t_sat)/2,4.6,'PHASE 2: Incubation-Operation','FontSize',11,'FontWeight','bold','Color',col.blue,'HorizontalAlignment','center');
text(ax,(t_sat+10)/2,4.6,'PHASE 3: Mature Development','FontSize',11,'FontWeight','bold','Color',col.green,'HorizontalAlignment','center');

% milestone markers
milestones = [0, t_inflect, first_CF_pos_year, t_sat, 10];
mlabels = {'Construction\ncomplete','Inflection\n(0.5K)','CF turns\npositive',...
           'Saturation\n(0.9K)','Yr10:\nGPI=0.51'};
mcol = [col.grey; col.orange; col.red; col.blue; col.green];
for k=1:numel(milestones)
    plot(ax,milestones(k),3,'o','MarkerSize',10,'MarkerFaceColor',mcol(k,:),'MarkerEdgeColor','k');
    text(ax,milestones(k),3.5,mlabels{k},'HorizontalAlignment','center','FontSize',8.5,...
         'Interpreter','tex');
end
plot(ax,[0 10],[3 3],'-','Color',[0.6 0.6 0.6],'LineWidth',1.2);

% bottom annotation: key targets per phase
text(ax,0.15,1.8,sprintf('CAPEX %.0fw\n%d HW/%d GPU',CAPEX,n_hw,n_comp),...
     'FontSize',8,'HorizontalAlignment','center','Color',col.grey);
text(ax,(0.3+t_sat)/2,1.8,sprintf('Occ 10%%->%.0f%%\nGPI %.2f->%.2f',...
     occ_rate(9)*100,GPI(2),GPI(9)),'FontSize',8,'HorizontalAlignment','center','Color',col.blue);
text(ax,(t_sat+10)/2,1.8,sprintf('Occ>90%%\nCF gap %.0fw',static_cumCF10),...
     'FontSize',8,'HorizontalAlignment','center','Color',col.green);

exportgraphics(f6,fullfile(outdir,'Fig6_roadmap.png'),'Resolution',300);

%% ========================================================================
%  6.  EXPORT TABLE
%  ========================================================================
T = table(Tspan(:), round(X(:,1),1),round(X(:,2),1),round(X(:,3),1),...
          round(X(:,4),1),round(X(:,5),1), round(GPI(:),3),...
          'VariableNames',{'Year','X_Seedling','X_Micro','X_Quality',...
          'X_PotentialUnicorn','X_Flagship','GPI'});
writetable(T,fullfile(outdir,'Q5_tier_evolution.csv'));

T2 = table(Tspan(2:11)',round(Innov_idx,3),round(Talent_idx,3),round(Cultivation_idx,3),...
          'VariableNames',{'Year','Innovation_Idx','Talent_Idx','Cultivation_Idx'});
writetable(T2,fullfile(outdir,'Q5_composite_indices.csv'));

disp(' '); disp('--- Tier evolution table ---'); disp(T);
disp(' '); disp('--- Composite indices table ---'); disp(T2);

%% ========================================================================
%  7.  SUMMARY
%  ========================================================================
fprintf('\n============================================================\n');
fprintf(' Q5 KEY OUTPUTS\n');
fprintf('============================================================\n');
fprintf(' Yr10 tier shares: S=%.1f%% M=%.1f%% Q=%.1f%% U=%.1f%% F=%.1f%%\n',pi_tier(11,:)*100);
fprintf(' Q3 target        : S=%.0f%%  M=%.0f%%  Q=%.0f%%  U=%.0f%%  F=%.0f%%\n',target*100);
fprintf(' Max deviation from Q3 target: %.1f pp\n',max(abs(pi_tier(11,:)-target))*100);
fprintf(' GPI: yr1=%.3f -> yr10=%.3f\n',GPI(2),GPI(11));
fprintf(' Innovation index: yr1=%.3f -> yr10=%.3f\n',Innov_idx(1),Innov_idx(10));
fprintf(' Talent index    : yr1=%.3f -> yr10=%.3f\n',Talent_idx(1),Talent_idx(10));
fprintf(' Phase boundaries: [0, %.2f, 10] yr (construction | incub-ops | mature)\n',t_sat);
fprintf(' 6 figures saved to: %s\n',outdir);
fprintf('============================================================\n');

%% ========================================================================
%  helper functions
%  ========================================================================
function w = entropy_w(M)
% Entropy weighting: M is n(samples) x m(indicators), returns 1xm weights
    Mn = (M - min(M)) ./ (max(M)-min(M) + 1e-12);
    Mn = Mn + 1e-9;
    P  = Mn ./ sum(Mn,1);
    n  = size(M,1);
    e  = -1/log(n) * sum(P.*log(P),1);
    d  = 1 - e;
    w  = (d/sum(d))';
end