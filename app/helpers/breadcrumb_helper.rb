module BreadcrumbHelper
  # Pages call `breadcrumb "Kitchen Cabinet", path` for a specific trail.
  # Every other page gets Dashboard (or Console) plus the section, so the header is never empty.
  def breadcrumb(label, path = nil)
    @breadcrumb_items ||= []
    @breadcrumb_items << { label: label.to_s, path: path }
  end

  def breadcrumb_items
    items = @breadcrumb_items.presence || automatic_breadcrumb_items
    prefix_root(items)
  end

  private

  def prefix_root(items)
    root_label = console_page? ? t("nav.console") : t("nav.dashboard")
    return items if items.first && items.first[:label] == root_label

    path = console_page? ? console_root_path : root_path
    [ { label: root_label, path: path } ] + items
  end

  def console_page?
    controller_path.start_with?("console/")
  end

  def automatic_breadcrumb_items
    console_page? ? console_breadcrumb_items : org_breadcrumb_items
  end

  def org_breadcrumb_items
    return [ { label: t("nav.dashboard"), path: nil } ] if controller_path == "home"

    label, path = org_section
    return [ { label: page_title, path: nil } ] if label.blank?

    items = [ { label: label, path: path } ]
    if action_name == "index"
      items.last[:path] = nil
    else
      tail = page_title
      items << { label: tail, path: nil } if tail.present? && tail != label
    end
    items
  end

  def org_section
    {
      "election_results" => [ t("nav.election_result"), election_result_path ],
      "account/passwords" => [ t("nav.change_password"), edit_account_password_path ],
      "kitchen_cabinet/tickets" => [ t("nav.beneficiaries"), kitchen_cabinet_tickets_path ],
      "kitchen_cabinet/closures" => [ t("nav.beneficiaries"), kitchen_cabinet_tickets_path ],
      "kitchen_cabinet/follow_ups" => [ t("nav.beneficiaries"), kitchen_cabinet_tickets_path ],
      "cadre_program/activities" => [ t("nav.cadre_program"), cadre_program_activities_path ],
      "ground_reports/villages" => [ t("nav.ground_reports"), ground_reports_villages_path ],
      "ground_reports/reports" => [ t("nav.ground_reports"), ground_reports_villages_path ],
      "ground_reports/imports" => [ t("nav.ground_reports"), ground_reports_villages_path ],
      "users" => [ t("nav.team"), users_path ],
      "support_tickets" => [ t("nav.support"), support_tickets_path ],
      "pr_records" => [ t("nav.pr_records"), pr_records_path ],
      "voter_lists/talukas" => [ t("nav.talukas"), voter_lists_talukas_path ],
      "voter_lists/villages" => [ t("nav.talukas"), voter_lists_talukas_path ],
      "voters" => [ t("nav.voter_lists"), voters_path ]
    }[controller_path]
  end

  def console_breadcrumb_items
    return [ { label: "Platform Console", path: nil } ] if controller_name == "dashboard"

    title = page_title
    section_path = console_section_path
    section = controller_name.humanize
    if section_path && action_name != "index" && section != title
      [ { label: section, path: section_path }, { label: title, path: nil } ]
    else
      [ { label: title, path: nil } ]
    end
  end

  def console_section_path
    if controller_name == "politicians" && defined?(@organization) && @organization
      console_organization_politicians_path(@organization)
    elsif controller_name == "org_tickets" && defined?(@organization) && @organization
      console_organization_path(@organization)
    elsif controller_name.in?(%w[platform_health dashboard])
      nil
    else
      helper = :"console_#{controller_name}_path"
      respond_to?(helper) ? public_send(helper) : nil
    end
  end

  def page_title
    raw = content_for(:title).to_s.strip
    return controller_name.humanize if raw.blank?

    raw.split(/\s*·\s*/).first.to_s.strip.presence || controller_name.humanize
  end
end
