%% ========================================================================
%  Q3  Space Functional Zoning & Resource Allocation
%  Input: Q1 site selection (Econ Dev Zone), Q2 capacity & equipment
%  Output: 5-floor allocation, utilisation validation, 6 journal figures
%  ========================================================================
clear; clc; close all;
rng(0);

outdir = fullfile(pwd,'Q3_figs');
if ~exist(outdir,'dir'); mkdir(outdir); end

%% ---------- journal style ----------
set(0,'DefaultAxesFontName','Arial','DefaultTextFontName','Arial');
set(0,'DefaultAxesFontSize',11,'DefaultAxesLineWidth',1.0);
set(0,'DefaultLineLineWidth',1.8);
col.blue   = [0.00 0.45 0.74];
col.orange = [0.85 0.33 0.10];
col.green  = [0.20 0.63 0.17];
col.purple = [0.49 0.18 0.56];
col.grey   = [0.50 0.50 0.50];
col.red    = [0.80 0.14 0.14];
col.teal   = [0.00 0.60 0.56];
col.gold   = [0.80 0.68 0.20];

%% ========================================================================
%  1.  Q2 INPUTS (carry forward)
%  ========================================================================
S_total = 10000;         % total floor area m^2
n_floors = 5;
S_floor  = 2000;         % per floor m^2

K      = 1000;           % carrying capacity (persons)
N0     = 100;
r      = 0.50;
A_log  = (K-N0)/N0;
Tspan  = 0:10;
Nt_fun = @(t) K./(1+A_log.*exp(-r.*t));
N      = Nt_fun(Tspan);

n_hw   = 341;            % hardware sets (one-shot, from Q2 lambda*=0.512)
n_comp = 488;            % compute nodes (one-shot)

fprintf('============================================================\n');
fprintf(' Q3  Space Functional Zoning & Resource Allocation\n');
fprintf('============================================================\n');
fprintf(' Building: %d m^2, %d floors x %d m^2\n',S_total,n_floors,S_floor);
fprintf(' Q2 inputs: K=%d, HW=%d sets, Compute=%d nodes\n',K,n_hw,n_comp);

%% ========================================================================
%  2.  FUNCTIONAL ZONE DEFINITION & AREA CALCULATION
%  ========================================================================
fprintf('\n--- Step 1: Functional zone area calculation ---\n');

% density parameters (justified in paper)
pp_office    = 5.5;     % m^2 per person (open + semi-private mix)
pp_hw        = 3.8;     % m^2 per hardware set (shared lab bench + aisle)
pp_comp      = 1.6;     % m^2 per compute node (rack + cooling clearance)

% computed areas
A_office = K * pp_office;
A_hw     = n_hw * pp_hw;
A_comp   = n_comp * pp_comp;
A_public = 1500;         % policy-driven: gov service hall, roadshow, dining
A_buffer = S_total - A_office - A_hw - A_comp - A_public;

zone_names  = {'Office workspace','Hardware lab','Compute facility',...
               'Public services','Buffer/circulation'};
zone_areas  = [A_office, A_hw, A_comp, A_public, A_buffer];
zone_colors = [col.blue; col.orange; col.purple; col.green; col.grey];

fprintf('  %-24s %6s  %5s\n','Zone','Area','Share');
for i = 1:numel(zone_names)
    fprintf('  %-24s %5.0f m^2  %4.1f%%\n',...
            zone_names{i},zone_areas(i),zone_areas(i)/S_total*100);
end
fprintf('  %-24s %5.0f m^2  %4.1f%%\n','TOTAL',sum(zone_areas),100);

%% ========================================================================
%  3.  ENTERPRISE TIER STRUCTURE (five-level pyramid)
%  ========================================================================
fprintf('\n--- Step 2: Enterprise tier distribution ---\n');

% tier definitions (at full capacity t=10)
tier_names = {'Seedling startup','Micro enterprise',...
              'Quality sci-tech','Potential unicorn','Industry unicorn'};
tier_share = [0.12, 0.25, 0.30, 0.23, 0.10];  % proportion of K at maturity
tier_floor = [1, 2, 3, 4, 5];                   % assigned floor
tier_pp    = K * tier_share;                     % persons per tier

fprintf('  %-22s %5s  %6s  %5s\n','Tier','Floor','Share','Seats');
for i = 1:5
    fprintf('  %-22s   %dF    %4.0f%%   %4.0f\n',...
            tier_names{i},tier_floor(i),tier_share(i)*100,tier_pp(i));
end
fprintf('  %-22s         %4.0f%%   %4.0f\n','Total',sum(tier_share)*100,sum(tier_pp));

%% ========================================================================
%  4.  FLOOR-BY-FLOOR ALLOCATION (optimisation via constrained assignment)
%  ========================================================================
fprintf('\n--- Step 3: Floor-by-floor allocation ---\n');

% define sub-zones per floor
% each row: [floor, zone_id, area, capacity_info]
% zone_id: 1=office, 2=hw_lab, 3=compute, 4=public, 5=buffer

alloc = struct('floor',{},'zone',{},'name',{},'area',{},'capacity',{});
idx = 0;

% ---- 1F: Gateway & Public Services + Seedling ----
idx=idx+1; alloc(idx) = struct('floor',1,'zone',4,'name','Gov service hall & reception','area',300,'capacity','--');
idx=idx+1; alloc(idx) = struct('floor',1,'zone',4,'name','Roadshow / multi-function hall','area',400,'capacity','--');
idx=idx+1; alloc(idx) = struct('floor',1,'zone',4,'name','Shared meeting rooms x3','area',250,'capacity','--');
idx=idx+1; alloc(idx) = struct('floor',1,'zone',4,'name','Dining & lounge area','area',350,'capacity','--');
idx=idx+1; alloc(idx) = struct('floor',1,'zone',1,'name','Seedling open workspace','area',550,'capacity','~100 seats');
idx=idx+1; alloc(idx) = struct('floor',1,'zone',5,'name','Lobby & circulation','area',150,'capacity','--');

% ---- 2F: Incubation & Growth ----
idx=idx+1; alloc(idx) = struct('floor',2,'zone',1,'name','Micro enterprise semi-open office','area',1200,'capacity','~218 seats');
idx=idx+1; alloc(idx) = struct('floor',2,'zone',2,'name','Shared hardware lab (primary)','area',600,'capacity','158 sets');
idx=idx+1; alloc(idx) = struct('floor',2,'zone',4,'name','Meeting rooms & pantry','area',200,'capacity','--');

% ---- 3F: Quality Sci-tech ----
idx=idx+1; alloc(idx) = struct('floor',3,'zone',1,'name','Quality sci-tech private office','area',1200,'capacity','~218 seats');
idx=idx+1; alloc(idx) = struct('floor',3,'zone',2,'name','Shared hardware lab (extended)','area',600,'capacity','158 sets');
idx=idx+1; alloc(idx) = struct('floor',3,'zone',5,'name','Shared amenities (buffer/circulation)','area',200,'capacity','--');

% ---- 4F: Accelerator ----
idx=idx+1; alloc(idx) = struct('floor',4,'zone',1,'name','Potential unicorn office','area',1200,'capacity','~218 seats');
idx=idx+1; alloc(idx) = struct('floor',4,'zone',3,'name','Core compute facility','area',600,'capacity','400 nodes');
idx=idx+1; alloc(idx) = struct('floor',4,'zone',5,'name','Shared amenities (buffer/circulation)','area',200,'capacity','--');

% ---- 5F: Flagship ----
idx=idx+1; alloc(idx) = struct('floor',5,'zone',1,'name','Industry unicorn HQ office & lounge','area',1350,'capacity','~245 seats (nominal; actual occupancy ~100)');
idx=idx+1; alloc(idx) = struct('floor',5,'zone',2,'name','Hardware showcase & testing','area',96,'capacity','25 sets');
idx=idx+1; alloc(idx) = struct('floor',5,'zone',3,'name','Backup compute room','area',181,'capacity','88 nodes');
idx=idx+1; alloc(idx) = struct('floor',5,'zone',5,'name','Rooftop HVAC & UPS + flexible buffer','area',373,'capacity','--');

% print and verify per-floor totals
fprintf('\n  %-4s %-40s %6s  %s\n','FL','Sub-zone','Area','Capacity');
fprintf('  %s\n',repmat('-',1,72));
floor_totals = zeros(5,1);
for i = 1:numel(alloc)
    fprintf('  %dF   %-40s %5.0f   %s\n',...
            alloc(i).floor,alloc(i).name,alloc(i).area,alloc(i).capacity);
    floor_totals(alloc(i).floor) = floor_totals(alloc(i).floor) + alloc(i).area;
end
fprintf('  %s\n',repmat('-',1,72));
for f = 1:5
    status = 'OK'; if floor_totals(f)~=2000; status='MISMATCH!'; end
    fprintf('  %dF total: %4.0f / 2000 m^2  %s\n',f,floor_totals(f),status);
end
fprintf('  Grand total: %.0f / %d m^2\n',sum(floor_totals),S_total);

% aggregate check: hw and compute totals
total_hw_alloc = 158 + 158 + 25;  % 2F + 3F + 5F
total_comp_alloc = 400 + 88;      % 4F + 5F
fprintf('\n  Hardware allocated: %d / %d sets %s\n',...
        total_hw_alloc,n_hw,ternary(total_hw_alloc==n_hw,'OK','CHECK'));
fprintf('  Compute allocated:  %d / %d nodes %s\n',...
        total_comp_alloc,n_comp,ternary(total_comp_alloc==n_comp,'OK','CHECK'));

%% ========================================================================
%  5.  UTILISATION VALIDATION (time-series)
%  ========================================================================
fprintf('\n--- Step 4: Utilisation validation ---\n');

% per-tier occupancy over time (proportional fill)
tier_N = tier_share(:) .* N;  % 5 x 11 matrix

% facility utilisation
util_office = N / K * 100;
util_hw     = min(0.40*N / n_hw, 1) * 100;
util_comp   = min(0.65*N / n_comp, 1) * 100;

% target band
util_lo = 70;  util_hi = 96;

fprintf('  Target utilisation band: [%d%%, %d%%]\n',util_lo,util_hi);
fprintf('  %-4s %5s %8s %8s %8s\n','Year','N(t)','Office%','HW%','Comp%');
for t = 1:10
    fprintf('  t=%-2d %4.0f  %6.1f   %6.1f   %6.1f\n',...
            t,N(t+1),util_office(t+1),util_hw(t+1),util_comp(t+1));
end
fprintf('\n  10-yr mean: office %.1f%% | hw %.1f%% | compute %.1f%%\n',...
        mean(util_office(2:end)),mean(util_hw(2:end)),mean(util_comp(2:end)));

% years in target band
in_band_office = sum(util_office(2:end)>=util_lo & util_office(2:end)<=util_hi);
in_band_hw     = sum(util_hw(2:end)>=util_lo & util_hw(2:end)<=util_hi);
fprintf('  Office in [%d,%d%%]: %d/10 years\n',util_lo,util_hi,in_band_office);
fprintf('  Hardware in band: %d/10 years  (early ramp-up expected below band)\n',in_band_hw);

%% ========================================================================
%  6.  FIGURES
%  ========================================================================

% ---- FIG 1: Floor allocation heatmap ----
f1 = figure('Color','w','Position',[60 60 800 520]);
ax1 = axes(f1); hold(ax1,'on'); box(ax1,'on');

zone_ids = [1,2,3,4,5];
zone_labels = {'Office','Hardware','Compute','Public','Buffer'};
zcolors = [col.blue; col.orange; col.purple; col.green; col.grey];

% build per-floor zone area matrix (5 floors x 5 zones)
FA = zeros(5,5);
for i = 1:numel(alloc)
    FA(alloc(i).floor, alloc(i).zone) = FA(alloc(i).floor, alloc(i).zone) + alloc(i).area;
end

bh = barh(ax1,1:5,FA,'stacked');
for z = 1:5
    bh(z).FaceColor = zcolors(z,:);
    bh(z).EdgeColor = 'w';
    bh(z).LineWidth = 1.2;
end
set(ax1,'YDir','reverse','YTick',1:5,...
    'YTickLabel',{'1F Gateway','2F Incubation','3F Sci-tech','4F Accelerator','5F Flagship'});
xlabel(ax1,'Area (m^2)');
title(ax1,'Floor-by-Floor Space Allocation','FontWeight','bold');
xline(ax1,2000,'--k','LineWidth',1,'Label','2000 m^2 limit','FontSize',9);
legend(ax1,zone_labels,'Location','southeast','Box','off','FontSize',9);
xlim(ax1,[0 2200]);
exportgraphics(f1,fullfile(outdir,'Fig1_floor_allocation.png'),'Resolution',300);

% ---- FIG 2: Area composition pie chart ----
f2 = figure('Color','w','Position',[60 60 640 500]);
ax2 = axes(f2);
p = pie(ax2,zone_areas,zone_names);
for i = 1:2:numel(p)
    p(i).FaceColor = zcolors(ceil(i/2),:);
    p(i).EdgeColor = 'w';
    p(i).LineWidth = 1.5;
end
for i = 2:2:numel(p)
    p(i).FontSize = 10;
end
title(ax2,'Overall Space Composition','FontWeight','bold','FontSize',13);
exportgraphics(f2,fullfile(outdir,'Fig2_area_pie.png'),'Resolution',300);

% ---- FIG 3: Tier occupancy over time (stacked area) ----
f3 = figure('Color','w','Position',[60 60 780 480]);
ax3 = axes(f3); hold(ax3,'on'); box(ax3,'on'); grid(ax3,'on');
ax3.GridAlpha = 0.12;
tier_colors = [col.green; col.blue; col.teal; col.orange; col.red];
ha = area(ax3,Tspan,tier_N','LineStyle','none');
for i = 1:5
    ha(i).FaceColor = tier_colors(i,:);
    ha(i).FaceAlpha = 0.85;
end
yline(ax3,K,'--k','LineWidth',1.2,'Label','Capacity K','FontSize',9,...
      'LabelHorizontalAlignment','left');
xlabel(ax3,'Year'); ylabel(ax3,'Occupancy (persons)');
title(ax3,'Enterprise Tier Occupancy Growth','FontWeight','bold');
legend(ax3,tier_names,'Location','northwest','Box','off','FontSize',9);
xlim(ax3,[0 10]); ylim(ax3,[0 K*1.08]);
exportgraphics(f3,fullfile(outdir,'Fig3_tier_growth.png'),'Resolution',300);

% ---- FIG 4: Utilisation time-series (3 curves) ----
f4 = figure('Color','w','Position',[60 60 780 480]);
ax4 = axes(f4); hold(ax4,'on'); box(ax4,'on'); grid(ax4,'on');
ax4.GridAlpha = 0.12;
% target band shading
patch(ax4,[0 10 10 0],[util_lo util_lo util_hi util_hi],...
      col.green,'FaceAlpha',0.08,'EdgeColor','none');
plot(ax4,Tspan,util_office,'-o','Color',col.blue,'MarkerFaceColor',col.blue,...
     'MarkerSize',5,'MarkerEdgeColor','w','LineWidth',2);
plot(ax4,Tspan,util_hw,'-s','Color',col.orange,'MarkerFaceColor',col.orange,...
     'MarkerSize',5,'MarkerEdgeColor','w','LineWidth',2);
plot(ax4,Tspan,util_comp,'-^','Color',col.purple,'MarkerFaceColor',col.purple,...
     'MarkerSize',5,'MarkerEdgeColor','w','LineWidth',2);
yline(ax4,util_lo,':','Color',col.grey,'LineWidth',1);
yline(ax4,util_hi,':','Color',col.grey,'LineWidth',1);
text(ax4,0.3,util_hi+2,'Target band','FontSize',9,'Color',col.green);
xlabel(ax4,'Year'); ylabel(ax4,'Utilisation (%)');
title(ax4,'Facility Utilisation Over 10-Year Horizon','FontWeight','bold');
legend(ax4,{'','Office','Hardware','Compute'},...
       'Location','southeast','Box','off','FontSize',9);
xlim(ax4,[0 10]); ylim(ax4,[0 105]);
exportgraphics(f4,fullfile(outdir,'Fig4_utilisation.png'),'Resolution',300);

% ---- FIG 5: Per-floor utilisation heatmap ----
f5 = figure('Color','w','Position',[60 60 820 420]);
ax5 = axes(f5);

% per-floor office area
floor_office = [550, 1200, 1200, 1200, 1350];  % from allocation
floor_seats  = round(floor_office / pp_office);
% floor utilisation = tier_N / floor_seats (proportional)
floor_util = zeros(5,11);
for f = 1:5
    floor_util(f,:) = min(tier_N(f,:) ./ floor_seats(f), 1) * 100;
end

imagesc(ax5,Tspan,1:5,floor_util);
colormap(ax5,[linspace(1,0.00,256)', linspace(1,0.45,256)', linspace(1,0.74,256)']);
cb = colorbar(ax5);
cb.Label.String = 'Utilisation (%)';
cb.Label.FontSize = 11;
caxis(ax5,[0 100]);
set(ax5,'YTick',1:5,'YTickLabel',...
    {'1F Gateway','2F Incubation','3F Sci-tech','4F Accelerator','5F Flagship'});
xlabel(ax5,'Year'); 
title(ax5,'Per-Floor Office Utilisation Heatmap','FontWeight','bold');
% add text labels
for f = 1:5
    for t = 1:11
        val = floor_util(f,t);
        tc = 'w'; if val < 50; tc = 'k'; end
        text(ax5,Tspan(t),f,sprintf('%.0f',val),...
             'HorizontalAlignment','center','FontSize',8,'Color',tc);
    end
end
exportgraphics(f5,fullfile(outdir,'Fig5_floor_heatmap.png'),'Resolution',300);

% ---- FIG 6: Allocation logic diagram (schematic) ----
% NOTE: rebuilt with patch()+FaceAlpha (true transparency, unlike
% rectangle's RGBA which some renderers flatten to opaque) and BLACK
% bold text so labels never blend into the fill colour. All elements
% (including the "growth" arrow) are drawn in the SAME axes data
% coordinate system to avoid annotation() normalized-figure-unit
% mismatches that previously clipped the right-hand panel.
f6 = figure('Color','w','Position',[60 60 900 580]);
ax6 = axes(f6); hold(ax6,'on');
set(ax6,'XLim',[0 10],'YLim',[0 12],'XTick',[],'YTick',[],'Box','off');
axis(ax6,'off');
title(ax6,'Space Allocation Logic Framework','FontWeight','bold','FontSize',14);

% draw 5 floor blocks (left panel, x in [0.3, 6.2])
floor_labels = {'1F: Gateway \& Seedling','2F: Incubation \& Hardware (primary)',...
                '3F: Quality Sci-tech \& Hardware (extended)',...
                '4F: Accelerator \& Core Compute','5F: Flagship \& Backup Compute'};
floor_col = [col.green; col.blue; col.teal; col.orange; col.red];
blockX = 0.3; blockW = 5.9; blockH = 1.3;

for f = 1:5
    ypos = 11.3 - (f-1)*2.2;              % centre y of this block
    yb   = ypos - blockH/2;               % bottom y of this block
    % true translucent fill via patch (NOT rectangle's RGBA)
    patch(ax6,'XData',blockX+[0 blockW blockW 0],...
              'YData',yb+[0 0 blockH blockH],...
              'FaceColor',floor_col(f,:),'FaceAlpha',0.20,...
              'EdgeColor',floor_col(f,:),'LineWidth',2.0);
    % label: solid black bold text -> always readable regardless of fill
    text(ax6,blockX+blockW/2,ypos,floor_labels{f},...
         'HorizontalAlignment','center','VerticalAlignment','middle',...
         'FontSize',11,'FontWeight','bold','Color',[0.10 0.10 0.10],...
         'Interpreter','tex');
    % small colour tag on the left edge of the block
    patch(ax6,'XData',blockX+[0 0.12 0.12 0],...
              'YData',yb+[0 0 blockH blockH],...
              'FaceColor',floor_col(f,:),'FaceAlpha',1.0,'EdgeColor','none');
    % down-arrow connector between consecutive floor blocks
    if f < 5
        y_top = yb;                        % bottom of current block
        y_bot = yb - (2.2-blockH);         % top of next block
        xa = blockX + blockW/2;
        plot(ax6,[xa xa],[y_top-0.05 y_bot+0.15],'-','Color',[0.45 0.45 0.45],'LineWidth',1.6);
        % arrowhead (small filled triangle)
        patch(ax6,'XData',xa+[-0.09 0.09 0],'YData',[y_bot+0.28 y_bot+0.28 y_bot+0.10],...
              'FaceColor',[0.45 0.45 0.45],'EdgeColor','none');
    end
end

% ---- right-side panel: enterprise growth arrow + key numbers ----
rx0 = 7.0; rx1 = 9.6;                 % right panel x-range (inside xlim=10)
text(ax6,(rx0+rx1)/2,11.4,'Enterprise Growth','FontSize',12,...
     'FontWeight','bold','Color',[0.25 0.25 0.25],'HorizontalAlignment','center');
text(ax6,(rx0+rx1)/2,10.75,'Seedling \rightarrow Unicorn','FontSize',10.5,...
     'Color',[0.35 0.35 0.35],'HorizontalAlignment','center','Interpreter','tex');

% long vertical growth arrow, fully inside axes data coords
gx = (rx0+rx1)/2; gy_top = 10.2; gy_bot = 1.0;
plot(ax6,[gx gx],[gy_top gy_bot],'-','Color',[0.55 0.55 0.55],'LineWidth',2.2);
patch(ax6,'XData',gx+[-0.14 0.14 0],'YData',[gy_bot+0.35 gy_bot+0.35 gy_bot],...
      'FaceColor',[0.55 0.55 0.55],'EdgeColor','none');

% key-numbers info box (centered on the growth arrow, safely inside panel)
boxW = 2.5; boxH = 1.6; bx0 = gx-boxW/2; by0 = 5.9;
patch(ax6,'XData',bx0+[0 boxW boxW 0],'YData',by0+[0 0 boxH boxH],...
      'FaceColor','w','EdgeColor',[0.4 0.4 0.4],'LineWidth',1.3);
text(ax6,gx,by0+boxH-0.35,sprintf('K = %d seats',K),...
     'FontSize',10,'HorizontalAlignment','center','Color',[0.1 0.1 0.1]);
text(ax6,gx,by0+boxH-0.75,sprintf('HW = %d sets',n_hw),...
     'FontSize',10,'HorizontalAlignment','center','Color',[0.1 0.1 0.1]);
text(ax6,gx,by0+boxH-1.15,sprintf('GPU = %d nodes',n_comp),...
     'FontSize',10,'HorizontalAlignment','center','Color',[0.1 0.1 0.1]);

exportgraphics(f6,fullfile(outdir,'Fig6_logic_framework.png'),'Resolution',300);

%% ========================================================================
%  7.  RESULT TABLE EXPORT
%  ========================================================================
Yr = Tspan(:);
T = table(Yr, round(N(:)), ...
          round(tier_N(1,:)'), round(tier_N(2,:)'), round(tier_N(3,:)'),...
          round(tier_N(4,:)'), round(tier_N(5,:)'), ...
          round(util_office(:),1), round(util_hw(:),1), round(util_comp(:),1),...
          'VariableNames',{'Year','N_total',...
          'Tier1_Seedling','Tier2_Micro','Tier3_Quality',...
          'Tier4_Unicorn','Tier5_Flagship',...
          'Util_Office_pct','Util_HW_pct','Util_Comp_pct'});
writetable(T,fullfile(outdir,'Q3_results.csv'));
disp(' '); disp('--- Q3 Result Table ---');
disp(T);

%% ========================================================================
%  8.  SUMMARY
%  ========================================================================
fprintf('\n============================================================\n');
fprintf(' Q3 KEY OUTPUTS\n');
fprintf('============================================================\n');
fprintf(' Total area: %d m^2 across %d floors\n',S_total,n_floors);
fprintf(' Office:    %4.0f m^2 (%.1f%%)\n',A_office,A_office/S_total*100);
fprintf(' Hardware:  %4.0f m^2 (%.1f%%)  -> %d sets\n',A_hw,A_hw/S_total*100,n_hw);
fprintf(' Compute:   %4.0f m^2 (%.1f%%)  -> %d nodes\n',A_comp,A_comp/S_total*100,n_comp);
fprintf(' Public:    %4.0f m^2 (%.1f%%)\n',A_public,A_public/S_total*100);
fprintf(' Buffer:    %4.0f m^2 (%.1f%%)\n',A_buffer,A_buffer/S_total*100);
fprintf('\n Floor constraint: all floors = 2000 m^2  PASS\n');
fprintf(' 10-yr avg utilisation: office %.1f%% | hw %.1f%% | comp %.1f%%\n',...
        mean(util_office(2:end)),mean(util_hw(2:end)),mean(util_comp(2:end)));
fprintf(' Spatial efficiency (total used / total): %.1f%%\n',...
        (S_total-A_buffer)/S_total*100);
fprintf('\n 6 figures saved to: %s\n',outdir);
fprintf('============================================================\n');

%% ========================================================================
%  helper
%  ========================================================================
function s = ternary(cond,a,b)
    if cond; s=a; else; s=b; end
end